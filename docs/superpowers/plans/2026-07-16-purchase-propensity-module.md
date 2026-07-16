# Purchase Propensity Classifier (Module 8) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Human-in-the-loop note:** Unlike a typical software plan, Tasks 1 and 2 in this plan cannot be fully executed by an agent. BigQuery ML training requires the user's live, billing-enabled GCP credentials, which no agent (main session or subagent) has access to. Task 1 (writing the SQL) is agent-executable. Task 2 (running that SQL and reporting results back) is a **user action** — the agent's role there is to hand over exact instructions and then consume whatever the user reports. Tasks 3 and 4 are agent-executable but have a hard data dependency on Task 2's output. Recommend **Inline Execution** over Subagent-Driven for this plan — a fresh subagent dispatched for Task 2 would hit the same credential wall the main session does, so there's no parallelism to gain, only handoff overhead to add.

**Goal:** Ship Module 8 — a session-level purchase propensity classifier trained with BigQuery ML, evaluated across the pre-COVID/COVID-onset boundary, and documented the same way every other module in this project is: an auditable SQL file, a self-contained local notebook, and updated project docs.

**Architecture:** BigQuery ML (`CREATE MODEL`) does the feature aggregation, training, and evaluation entirely inside BigQuery — no local sampling, no new Python ML dependency. A local Jupyter notebook then hardcodes the small set of returned metrics (same pattern `notebooks/04_cohort_retention.ipynb` already uses for its cohort dict) and builds the portfolio-facing charts with matplotlib/seaborn, so the notebook runs standalone forever with zero GCP dependency.

**Tech Stack:** BigQuery SQL + BigQuery ML (`LOGISTIC_REG`), Jupyter/pandas/matplotlib/seaborn (already in `requirements.txt` — no new dependencies).

## Global Constraints

- Design spec: `docs/superpowers/specs/2026-07-16-purchase-propensity-design.md` — this plan implements it in full; do not deviate without updating the spec first.
- BigQuery project/dataset: `instant-form-500912-n7.rees46` (table `events`).
- Feature cutoff: first **3 events** per session (event-count based, not time-based — see spec for rationale).
- Period boundaries: reuse Module 7's exact definitions for consistency — Pre-COVID = `event_time` date `<= '2020-03-12'`, COVID onset = `>= '2020-03-16'`, transition window `2020-03-13`–`2020-03-15` excluded entirely, `2020-02-27` (confirmed logging gap) excluded entirely.
- No new Python dependencies — BQML trains in SQL; the notebook only visualizes already-computed results.
- SQL file header style: match `sql/07_covid_experiment.sql` — business question, table/scope note, methodology notes, a `VERIFIED RESULTS (run YYYY-MM-DD):` block filled in **after** the user runs the queries, then numbered `-- ====...` query sections.
- Notebook style: match `notebooks/04_cohort_retention.ipynb` exactly — same design-token setup cell (colors, `plt.rcParams`), markdown header with Platform/Where this fits/Business question, one markdown+code cell pair per figure, a closing "Summary of Findings" markdown cell with a results table and numbered insights.
- Git commit style: imperative, scoped prefix (`feat:`, `docs:`), 1–2 sentence body explaining why — match `git log --oneline -5` style already in this repo.

---

### Task 1: Write the Module 8 SQL file

**Files:**
- Create: `sql/08_purchase_propensity.sql`

**Interfaces:**
- Produces: table `instant-form-500912-n7.rees46.propensity_features` with columns `user_session, products_viewed, categories_viewed, min_price_viewed, max_price_viewed, avg_price_viewed, cart_in_cutoff, session_start_hour, session_start_dow, is_returning_user, prior_purchase_count, days_since_last_purchase, purchased_after_cutoff, is_covid_period` — Task 2 runs this and Task 3's notebook references these exact column names in its written commentary.
- Produces: model `instant-form-500912-n7.rees46.propensity_model` — consumed by Query 3 (`ML.EVALUATE`), Query 4 (`ML.ROC_CURVE`), and Query 5 (`ML.PREDICT`) later in the same file.
- Consumes: nothing — this task only writes the file, it does not run it.

- [ ] **Step 1: Write the full SQL file**

```sql
-- Module 8: Purchase Propensity Classifier
-- Business question: given only the first 3 events of a session, how likely is it to end in a purchase?
-- Table: instant-form-500912-n7.rees46.events (411,709,736 events, Oct 2019 – Apr 2020)
--
-- LABEL & CUTOFF:
--   Features are computed from each session's first 3 events only (event_rank 1-3).
--   Label = does a 'purchase' event occur among events ranked 4+ in that same session.
--   Sessions with 3 or fewer total events are excluded — there is nothing after the
--   cutoff to predict, so including them would just inject unlabeled noise.
--
-- WHY EVENT-COUNT CUTOFF, NOT TIME-BASED:
--   Data Quality Finding #4 (Funnel Floor Bias, see README) established that this dataset
--   has no landing-page/search/homepage event — "session start" here already means
--   "first product view," not real site arrival. A time-based cutoff (e.g. first 60
--   seconds) would measure an arbitrary window on top of an already-truncated start,
--   with an unknown amount of real browsing hidden before it. Event-count avoids that
--   compounding confound and is simpler to compute and explain.
--
-- PERIOD DEFINITIONS (reused verbatim from Module 7 for consistency):
--   Pre-COVID:   event date <= 2020-03-12
--   Transition:  2020-03-13 to 2020-03-15 — EXCLUDED (ambiguous treatment)
--   COVID onset: event date >= 2020-03-16
--   2020-02-27 excluded throughout (confirmed logging gap, z = -18.84)
--   A session's period is assigned by its first event's date.
--
-- TRAIN/TEST SPLIT:
--   Not a random holdout. Trained on pre-COVID sessions, evaluated on COVID-onset
--   sessions (DATA_SPLIT_METHOD='CUSTOM', DATA_SPLIT_COL='is_covid_period', TRUE=eval).
--   This turns evaluation into a generalization stress-test against the exact
--   behavioral shift Module 7's quasi-experiment already proved happened, rather than
--   an arbitrary percentage split.
--
-- RETURNING-USER FEATURES:
--   prior_purchase_count / days_since_last_purchase are computed from each user's
--   purchase history strictly BEFORE this session's first event — legitimately known
--   ahead of time, no leakage risk (unlike in-session features, which are frozen at
--   the 3-event cutoff specifically to avoid it).
--
-- EXECUTION ORDER (run in this order — Query 2 depends on Query 1's table existing,
-- Queries 3-5 depend on Query 2's model existing):
--   Query 1 — CREATE OR REPLACE TABLE propensity_features
--   Query 2 — CREATE OR REPLACE MODEL propensity_model
--   Query 3 — ML.EVALUATE (headline metrics: precision, recall, roc_auc, log_loss, accuracy, f1_score)
--   Query 4 — ML.ROC_CURVE (threshold sweep, for the ROC chart)
--   Query 5 — Decile lift table (business-framed: "top X% of scored sessions captures Y% of purchases")
--
-- VERIFIED RESULTS: pending — filled in after Task 2 (this file's queries have not
-- been run against live BigQuery yet as of writing this file).


-- ============================================================
-- Query 1: Feature engineering — session-level propensity features
-- One row per eligible session (session_length > 3, period assigned).
-- ============================================================
CREATE OR REPLACE TABLE `instant-form-500912-n7.rees46.propensity_features` AS
WITH ranked_events AS (
  SELECT
    user_session,
    user_id,
    event_type,
    event_time,
    price,
    product_id,
    category_code,
    ROW_NUMBER() OVER (PARTITION BY user_session ORDER BY event_time)      AS event_rank,
    COUNT(*) OVER (PARTITION BY user_session)                              AS session_length,
    SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) OVER (
      PARTITION BY user_id ORDER BY UNIX_SECONDS(event_time)
      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    )                                                                       AS prior_purchase_count,
    LAST_VALUE(CASE WHEN event_type = 'purchase' THEN event_time END IGNORE NULLS) OVER (
      PARTITION BY user_id ORDER BY UNIX_SECONDS(event_time)
      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    )                                                                       AS last_purchase_before
  FROM `instant-form-500912-n7.rees46.events`
  WHERE DATE(event_time) != '2020-02-27'
),
session_base AS (
  SELECT
    user_session,
    ANY_VALUE(user_id)                                    AS user_id,
    MIN(event_time)                                       AS session_start,
    MAX(session_length)                                   AS session_length,
    ANY_VALUE(prior_purchase_count HAVING MIN event_rank)  AS prior_purchase_count,
    ANY_VALUE(last_purchase_before HAVING MIN event_rank)  AS last_purchase_before,
    CASE
      WHEN DATE(MIN(event_time)) <= '2020-03-12' THEN 'pre_covid'
      WHEN DATE(MIN(event_time)) >= '2020-03-16' THEN 'covid_onset'
      ELSE NULL
    END                                                    AS period
  FROM ranked_events
  GROUP BY user_session
),
cutoff_window AS (
  SELECT
    user_session,
    COUNT(DISTINCT product_id)                                                        AS products_viewed,
    COUNT(DISTINCT SPLIT(COALESCE(category_code, 'unknown'), '.')[OFFSET(0)])         AS categories_viewed,
    MIN(price)                                                                        AS min_price_viewed,
    MAX(price)                                                                        AS max_price_viewed,
    ROUND(AVG(price), 2)                                                              AS avg_price_viewed,
    MAX(CASE WHEN event_type = 'cart' THEN 1 ELSE 0 END)                              AS cart_in_cutoff,
    EXTRACT(HOUR FROM MIN(event_time))                                                AS session_start_hour,
    EXTRACT(DAYOFWEEK FROM MIN(event_time))                                           AS session_start_dow
  FROM ranked_events
  WHERE event_rank <= 3
  GROUP BY user_session
),
label_window AS (
  SELECT
    user_session,
    MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchased_after_cutoff
  FROM ranked_events
  WHERE event_rank > 3
  GROUP BY user_session
)
SELECT
  sb.user_session,
  cw.products_viewed,
  cw.categories_viewed,
  cw.min_price_viewed,
  cw.max_price_viewed,
  cw.avg_price_viewed,
  cw.cart_in_cutoff,
  cw.session_start_hour,
  cw.session_start_dow,
  IFNULL(sb.prior_purchase_count, 0) > 0                                 AS is_returning_user,
  IFNULL(sb.prior_purchase_count, 0)                                     AS prior_purchase_count,
  DATE_DIFF(DATE(sb.session_start), DATE(sb.last_purchase_before), DAY)  AS days_since_last_purchase,
  CAST(lw.purchased_after_cutoff AS BOOL)                                AS purchased_after_cutoff,
  (sb.period = 'covid_onset')                                            AS is_covid_period
FROM session_base sb
JOIN cutoff_window cw USING (user_session)
JOIN label_window lw USING (user_session)
WHERE sb.period IS NOT NULL
  AND sb.session_length > 3;


-- ============================================================
-- Query 2: Train the model
-- LOGISTIC_REG for interpretability (coefficients map directly to "how much does
-- viewing one more category raise purchase odds" — a business-readable statement,
-- not a black box). AUTO_CLASS_WEIGHTS handles the ~6% positive-class imbalance.
-- user_session is an identifier, not a feature — excluded. is_covid_period and
-- purchased_after_cutoff are the split and label columns; BQML excludes both from
-- the actual feature set automatically.
-- ============================================================
CREATE OR REPLACE MODEL `instant-form-500912-n7.rees46.propensity_model`
OPTIONS (
  MODEL_TYPE = 'LOGISTIC_REG',
  INPUT_LABEL_COLS = ['purchased_after_cutoff'],
  DATA_SPLIT_METHOD = 'CUSTOM',
  DATA_SPLIT_COL = 'is_covid_period',
  AUTO_CLASS_WEIGHTS = TRUE
) AS
SELECT * EXCEPT(user_session)
FROM `instant-form-500912-n7.rees46.propensity_features`;


-- ============================================================
-- Query 3: Headline evaluation metrics
-- Evaluates against the held-out COVID-onset eval set from the CUSTOM split above.
-- ============================================================
SELECT *
FROM ML.EVALUATE(MODEL `instant-form-500912-n7.rees46.propensity_model`);


-- ============================================================
-- Query 4: ROC curve — full threshold sweep, for the notebook's ROC chart
-- ============================================================
SELECT *
FROM ML.ROC_CURVE(MODEL `instant-form-500912-n7.rees46.propensity_model`);


-- ============================================================
-- Query 5: Decile lift table
-- Business framing: "targeting the top N% of scored sessions captures what % of
-- all actual purchases" — more actionable to a stakeholder than AUC alone.
-- Scored against the same COVID-onset eval sessions used above.
-- ============================================================
WITH eval_scored AS (
  SELECT
    purchased_after_cutoff,
    (SELECT prob FROM UNNEST(predicted_purchased_after_cutoff_probs) WHERE label = TRUE) AS purchase_prob
  FROM ML.PREDICT(
    MODEL `instant-form-500912-n7.rees46.propensity_model`,
    (SELECT * FROM `instant-form-500912-n7.rees46.propensity_features` WHERE is_covid_period = TRUE)
  )
),
deciled AS (
  SELECT
    purchased_after_cutoff,
    purchase_prob,
    NTILE(10) OVER (ORDER BY purchase_prob DESC) AS score_decile
  FROM eval_scored
)
SELECT
  score_decile,
  COUNT(*)                                                                        AS sessions_in_decile,
  SUM(CAST(purchased_after_cutoff AS INT64))                                      AS purchases_in_decile,
  ROUND(SUM(CAST(purchased_after_cutoff AS INT64)) * 100.0 /
        SUM(SUM(CAST(purchased_after_cutoff AS INT64))) OVER (), 2)              AS pct_of_all_purchases_captured,
  ROUND(SUM(CAST(purchased_after_cutoff AS INT64)) * 100.0 / COUNT(*), 2)        AS purchase_rate_in_decile_pct,
  ROUND(AVG(purchase_prob) * 100.0, 2)                                            AS avg_predicted_prob_pct
FROM deciled
GROUP BY score_decile
ORDER BY score_decile;
```

- [ ] **Step 2: Self-review the file (no execution possible from this environment — `bq` CLI is installed but non-functional here, and BQML requires the user's live credentials anyway)**

Check, reading top to bottom:
- Every column Query 2 selects via `* EXCEPT(user_session)` exists in Query 1's final `SELECT` list — cross-check against the 14 columns listed in this task's Interfaces block above.
- Query 5's `predicted_purchased_after_cutoff_probs` name follows BQML's `predicted_<label_col>_probs` convention for `INPUT_LABEL_COLS = ['purchased_after_cutoff']` — flag this specific line as the one most likely to need a small correction once actually run (struct/array field naming is the one piece of syntax in this file not exercised elsewhere in this codebase).
- Table names are consistent across all 5 queries (`propensity_features`, `propensity_model`).

- [ ] **Step 3: Commit**

```bash
git add sql/08_purchase_propensity.sql
git commit -m "$(cat <<'EOF'
feat: add Module 8 purchase propensity SQL (feature engineering + BQML)

Not yet run against live BigQuery — Task 2 of the implementation plan
covers execution and capturing verified results.
EOF
)"
```

---

### Task 2: Run the queries in BigQuery Studio and capture results (user action)

**Files:** none created by the agent in this task — this task's output is the user's reported results, consumed by Task 1's follow-up edit (below) and by Task 3.

**Interfaces:**
- Consumes: `sql/08_purchase_propensity.sql` from Task 1.
- Produces: a results report (exact numbers) that Task 3's notebook and Task 1's `VERIFIED RESULTS` header both depend on. Report back, verbatim, in this shape:
  - Query 1: row count of `propensity_features` (`SELECT COUNT(*) FROM ...`) and the split: `SELECT is_covid_period, COUNT(*), SUM(CAST(purchased_after_cutoff AS INT64)) FROM propensity_features GROUP BY is_covid_period`
  - Query 3: the full `ML.EVALUATE` output row (precision, recall, accuracy, f1_score, log_loss, roc_auc)
  - Query 4: `ML.ROC_CURVE` output — doesn't need to be pasted in full (it can be hundreds of rows); report the threshold closest to 0.5 and the min/max thresholds, or just confirm it ran and paste 5-10 sample rows
  - Query 5: the full decile lift table (10 rows)
  - Confirmation the screenshot (see below) was captured

- [ ] **Step 1: Open BigQuery Studio in the browser, confirm the active project is `instant-form-500912-n7`**

- [ ] **Step 2: Paste and run Query 1 from `sql/08_purchase_propensity.sql`**

Expected: succeeds, creates `rees46.propensity_features`. Note the row count.
If it errors: paste the exact error message back — most likely culprits are a typo'd column name or an unsupported window-function combination; straightforward to fix once you have the real error text.

- [ ] **Step 3: Paste and run Query 2 (`CREATE OR REPLACE MODEL`)**

This is the one that takes real time (likely several minutes) and is the one query in this file that actually costs money beyond the free tier, given the full-population training set. Let it finish.

- [ ] **Step 4: While Query 2 or Query 3 is running/showing results, take the console screenshot**

Save as `dashboards/08_bqml_console.png` — capture the query editor with the SQL visible and, ideally, the `ML.EVALUATE` results table showing underneath. This is a process artifact (same category as `dashboards/image.png`, the Data Canvas EDA screenshot), not something that needs to be pretty — just real.

- [ ] **Step 5: Run Query 3, 4, and 5 in order, record their output**

- [ ] **Step 6: Report all results back** (row counts, `ML.EVALUATE` row, decile lift table, confirmation of the screenshot) so Task 1's file can be updated with `VERIFIED RESULTS` and Task 3 can be started

---

### Task 3: Build the local notebook

**Files:**
- Create: `notebooks/08_purchase_propensity.ipynb`
- Modify: `sql/08_purchase_propensity.sql` (replace the `VERIFIED RESULTS: pending` line with the real numbers from Task 2, same pattern as `sql/07_covid_experiment.sql`'s header)

**Interfaces:**
- Consumes: Task 2's reported numbers (ML.EVALUATE row, ROC curve points, decile lift table).
- Produces: `notebooks/08_fig1_roc_curve.png`, `notebooks/08_fig2_calibration.png`, `notebooks/08_fig3_decile_lift.png` (saved by the notebook itself, same pattern as `notebooks/04_fig1_cohort_heatmap.png`).

- [ ] **Step 1: Update Query 2's header comment block in `sql/08_purchase_propensity.sql`**

Replace `-- VERIFIED RESULTS: pending — filled in after Task 2 ...` with the actual reported numbers, formatted the same way as `sql/07_covid_experiment.sql`'s `VERIFIED RESULTS (run YYYY-MM-DD):` block — the metrics table, the decile lift table, and 3-5 bullet "Key insights" (e.g. which features carried the most weight, how much lift the top decile captured, whether the model held up on COVID-onset sessions or degraded).

- [ ] **Step 2: Build the notebook's setup cell**

Reuse the exact design-token block from `notebooks/04_cohort_retention.ipynb` verbatim (imports, `C_SURFACE`/`C_PRIMARY`/`C_SECONDARY`/`C_MUTED`/`C_GRID`/`C_AXIS`/`C_S1`, `plt.rcParams.update({...})`) — do not redefine a new palette, this project's dataviz convention is one shared token set across all notebooks.

- [ ] **Step 3: Build the header markdown cell**

Follow the `04_cohort_retention.ipynb` header structure: `# Module 8 — Purchase Propensity`, then **Platform**, **Where this fits in the project** (ties to Module 1's funnel and Module 7's COVID quasi-experiment), **Business question**, and a caveat callout paragraph covering the event-count-cutoff rationale and the minimum-session-length exclusion — same voice as the existing caveat callouts.

- [ ] **Step 4: Build the ROC curve figure**

Markdown header cell (what the chart shows + a "Reading it:" paragraph), then a code cell that hardcodes the `ML.ROC_CURVE` points reported in Task 2 as a small list of `(threshold, recall, false_positive_rate)` tuples — following the exact hardcoded-dict-from-query-results pattern `04_cohort_retention.ipynb` uses for `cohort_retention = {...}` — plots the ROC curve with the project's line/fill style (`C_S1`, `alpha=0.12` fill, direct labels, no default legend), saves to `notebooks/08_fig1_roc_curve.png`, prints a 2-3 line finding.

- [ ] **Step 5: Build the calibration chart**

Bucket the `ML.PREDICT` probabilities Task 2 reported (or, if not bucketed by the user, note this as a known gap and fall back to reporting `ML.EVALUATE`'s `log_loss` as the calibration proxy) into 10 probability bins, plot predicted vs. actual purchase rate per bin against the diagonal reference line, saves to `notebooks/08_fig2_calibration.png`.

- [ ] **Step 6: Build the decile lift chart**

Hardcode the Query 5 decile lift table from Task 2 as a small list of dicts, plot as a bar chart (`pct_of_all_purchases_captured` per decile) with a callout on the top decile's capture rate, saves to `notebooks/08_fig3_decile_lift.png`.

- [ ] **Step 7: Build the closing "Summary of Findings" markdown cell**

Results table + 4-6 numbered insight bullets, same format as `04_cohort_retention.ipynb`'s closing cell — cover: overall AUC, what the top decile captures, which features mattered most (from the model's learned weights, visible via `ML.WEIGHTS` if the user wants to run that as a bonus query, otherwise omit), and whether performance held up evaluating on COVID-onset sessions vs. what pre-COVID training would suggest.

- [ ] **Step 8: Commit**

```bash
git add sql/08_purchase_propensity.sql notebooks/08_purchase_propensity.ipynb notebooks/08_fig1_roc_curve.png notebooks/08_fig2_calibration.png notebooks/08_fig3_decile_lift.png dashboards/08_bqml_console.png
git commit -m "$(cat <<'EOF'
feat: verify Module 8 results and build purchase propensity notebook

Captures BQML training/evaluation output as static data so the notebook
runs standalone with no live BigQuery dependency, matching the pattern
already used by Modules 3, 4, and 7.
EOF
)"
```

---

### Task 4: Update project documentation

**Files:**
- Modify: `README.md` (Analytics Deliverables list, Stack section)
- Modify: `workflows/02_analytics_plan.md` (Build Order, Output Artifacts)

**Interfaces:**
- Consumes: Task 3's finished notebook and Task 2's headline numbers (for the Analytics Deliverables description).

- [ ] **Step 1: Add Module 8 to README's Analytics Deliverables list**

Insert after the existing "7. COVID Quasi-Experiment" section:

```markdown
### 8. Purchase Propensity
**Question:** Given only the first 3 events of a session, how likely is it to end in a purchase?
- Session-level logistic regression, trained and evaluated in BigQuery ML
- Feature cutoff at event 3 (not time-based — see Data Quality Finding #4 on why)
- Evaluated on COVID-onset sessions after training on pre-COVID sessions, as a generalization stress-test against Module 7's confirmed behavioral shift
- Decile lift table: what % of purchases are captured by targeting the highest-scored sessions
```

(Fill in the actual AUC / top-decile-capture numbers from Task 2's results once known, matching the specificity of the existing 7 module descriptions.)

- [ ] **Step 2: Add the Real-world note to README's Stack section**

Insert after the existing "Real-world note on the Power BI report" paragraph:

```markdown
**Real-world note on the propensity model:** In a real production environment, this classifier would be trained and served directly on the data platform — BigQuery ML's `CREATE MODEL`, retrained on a schedule, with `ML.PREDICT` scoring live sessions in place, so the model always reflects current behavior without data ever leaving the warehouse. That live, in-platform serving approach was intentionally not used as the final deliverable here: a portfolio artifact needs to stay inspectable and re-runnable by someone who doesn't have access to this project's billing-enabled BigQuery account. BigQuery ML was used to actually train and evaluate the model (see `sql/08_purchase_propensity.sql`), but the results were captured as static output and moved into a local notebook (`notebooks/08_purchase_propensity.ipynb`) for the final write-up and charts — self-contained and inspectable indefinitely, the same reasoning already applied to the Excel workbook and the Power BI report above.
```

- [ ] **Step 3: Add Module 8 to `workflows/02_analytics_plan.md`'s Build Order and Output Artifacts sections**

Build Order: append `Module 8: Purchase Propensity     ← depends on Module 7 for the COVID period boundaries it reuses`.
Output Artifacts: add `sql/08_purchase_propensity.sql`, `notebooks/08_purchase_propensity.ipynb`, and `dashboards/08_bqml_console.png` to the existing file trees.

- [ ] **Step 4: Commit**

```bash
git add README.md workflows/02_analytics_plan.md
git commit -m "$(cat <<'EOF'
docs: document Module 8 in README and analytics plan
EOF
)"
```
