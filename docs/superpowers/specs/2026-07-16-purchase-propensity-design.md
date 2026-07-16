# Purchase Propensity Classifier — Design Spec

## Objective

Add Module 8 to the analytics build: a session-level classifier that predicts, from the earliest observable behavior in a session, whether that session will end in a purchase. This is the literal claim the README's opening line already makes ("identifies the behavioral signals that predict who converts") but that no module currently delivers — Modules 1–7 are descriptive/diagnostic, not predictive.

## Scope decision

Single flagship model only — purchase propensity. Considered and deliberately excluded:

- **Churn/winback** — real signal exists (M1 repeat-purchase rate averages ~19% across cohorts per `notebooks/04_cohort_retention.ipynb`), but ~39% of first-time purchasers (Feb–Apr 2020 cohorts, ~804K users) have no closed observation window before the dataset ends — a right-censoring problem that would need careful, disclosed handling. Set aside for scope, not ruled out for the future.
- **Demand forecasting** — workable for short-horizon technique demonstration on 213 daily data points, but the trailing two months are a known regime break (COVID onset), so "predicting the future" framing doesn't hold up honestly with this data. Would need reframing as change-point quantification, not attempted here.
- **Fraud/bot scoring as a real model** — Module 6 already covers this with rule-based IQR + event-count thresholds; upgrading to a genuine anomaly-detection model was considered lower priority than shipping one model well.
- **Recommendation/next-product prediction** — REES46's actual core product; too heavy a build (implicit-feedback techniques) for this project's scope.

Rationale for going narrow: better to ship one model with rigorous, honest handling of its real limitations than several done shallowly — consistent with how the existing Data Quality Findings are written (thorough > numerous).

## Prediction target & label

**Grain:** session-level, not user-level. Matches the grain Module 1 (Funnel) already established.

**Label:** does a `purchase` event occur anywhere in the session, evaluated from a frozen cutoff point onward.

## Cutoff method: event-count based (not time-based)

Freeze features at the first **3 events** per session (`ROW_NUMBER() OVER (PARTITION BY user_session ORDER BY event_time)`, same window-function pattern as Module 2), predict from events after that point. N=3 is the working default — enough to compute meaningful aggregates (distinct products/categories, price range) while still being an early-session cutoff; revisit only if evaluation shows it's uninformative.

**Time-based cutoff (first N seconds) was considered and rejected**, for a reason grounded in this project's own prior finding: Data Quality Finding #4 (Funnel Floor Bias) already established that this dataset has no landing-page/search/homepage event — "session start" in the data means "first product view," not real site arrival. A time-based cutoff would measure an arbitrary window on top of an already-truncated starting point, with an unknown amount of real browsing time hidden before it — a second, compounding confound. Event-count cutoff avoids this entirely and is simpler to compute and explain.

**Disclosed scoping limitation:** sessions shorter than the cutoff (no events remain after freezing) must be excluded from the labeled population. This exclusion should be written up the same way the existing four Data Quality Findings are — what was found, what it means, how it's handled.

## Feature engineering

From pre-cutoff events only: distinct products/categories viewed, min/max/avg price viewed, whether a cart event already occurred before cutoff, hour-of-day/day-of-week from `event_time`. For returning users: prior RFM tier, past purchase count, recency — legitimately known before the session starts, no leakage risk.

## Platform: BigQuery ML, with a local notebook for the write-up

**Training/evaluation:** BigQuery ML (`CREATE MODEL ... OPTIONS(MODEL_TYPE='LOGISTIC_REG', ...)`), trained on the full session population — no local sampling needed, since this is SQL-native aggregation the same way every other module already works at BigQuery scale. `ML.EVALUATE` and `ML.ROC_CURVE` provide the metrics.

**Why BQML over local scikit-learn:** removes the local-sampling design problem entirely (full population, no downsampling bias to defend), stays SQL-native like the rest of the project, and doesn't require adding a new dependency to `requirements.txt`.

**Why BQML over a BigQuery Studio Python notebook:** BigFrames/BigQuery Studio notebooks have no offline execution mode (confirmed via Google's own docs) — they require live `gcloud auth application-default login` credentials tied to a real GCP project with billing and dataset access. A downloaded copy would not run for anyone but the account owner. This defeats the point of a portfolio artifact.

**Local notebook's actual job:** `notebooks/08_purchase_propensity.ipynb` does *not* train anything. It hardcodes the metrics `ML.EVALUATE`/`ML.ROC_CURVE` returned (same pattern already used in `notebooks/04_cohort_retention.ipynb`, which hardcodes `cohort_retention = {...}` from a captured query result) and builds the polished ROC curve, calibration plot, and decile-lift chart locally with the project's existing dataviz tokens. Runs standalone forever, no GCP credentials required, matches the project's established self-contained-artifact philosophy (same reasoning as the Excel workbook and Power BI Import mode).

**Verification path for a reviewer:** `sql/08_purchase_propensity.sql` is the auditable proof of methodology — plain text, and anyone with their own BigQuery access can re-run it against the same public dataset and check the numbers match. This is the same verification path the rest of the project already relies on.

## Train/test split: time-based, not random

Train on pre-COVID months (Oct 2019–Feb 2020), evaluate on COVID-onset months (Mar–Apr 2020) — via BQML's `DATA_SPLIT_METHOD='CUSTOM'` with an explicit boolean split column (not the default `SEQ` 70/30, which wouldn't land exactly on the COVID boundary).

This isn't a random holdout for its own sake — it turns model evaluation into a generalization stress-test against the exact behavioral shift Module 7's quasi-experiment already proved happened, tying Module 8 back into the project's actual through-line instead of being an unrelated ML exercise bolted on. Terminology note: this is a train/test split (does the model generalize to unseen data), not a control-group experiment (that's what Module 7 already is).

## Evaluation

ROC-AUC / PR-AUC (base rate ~6%, so plain accuracy is meaningless), a calibration check, and a decile lift table framed for a business audience ("targeting the top 10% of scored sessions captures Y% of all purchases") — more actionable to a stakeholder than an AUC number alone.

## New artifacts

```text
sql/08_purchase_propensity.sql          — feature engineering + CREATE MODEL + ML.EVALUATE + ML.ROC_CURVE
notebooks/08_purchase_propensity.ipynb  — captures results as static data, produces charts
dashboards/08_bqml_console.png          — screenshot of the BigQuery SQL editor mid-execution (process artifact, not analytical deliverable — same category as the existing Data Canvas EDA screenshot)
```

No new Python dependency required — BQML does the modeling in SQL; the local notebook only visualizes already-computed, hardcoded results.

## Real-world note (to add to README's Stack section, alongside the existing Excel/Power BI real-world notes, once Module 8 ships)

> **Real-world note on the propensity model:** In a real production environment, this classifier would be trained and served directly on the data platform — BigQuery ML's `CREATE MODEL`, retrained on a schedule, with `ML.PREDICT` scoring live sessions in place, so the model always reflects current behavior without data ever leaving the warehouse. That live, in-platform serving approach was intentionally not used as the final deliverable here: a portfolio artifact needs to stay inspectable and re-runnable by someone who doesn't have access to this project's billing-enabled BigQuery account. BigQuery ML was used to actually train and evaluate the model (see `sql/08_purchase_propensity.sql`), but the results were captured as static output and moved into a local notebook (`notebooks/08_purchase_propensity.ipynb`) for the final write-up and charts — self-contained and inspectable indefinitely, the same reasoning already applied to the Excel workbook and the Power BI report above.

## Housekeeping surfaced during this design (not part of Module 8, flagged separately)

`dashboards/image.png` is the Data Canvas EDA screenshot referenced in `workflows/02_analytics_plan.md` as `dashboards/00_data_canvas_eda.png` — the file exists but under the wrong name; the doc reference has never matched the actual filename. Needs a decision: rename the file, or fix the doc reference. Not addressed in this spec.

## Documentation updates needed at implementation time

- `README.md` — add Module 8 to Analytics Deliverables list; add the Real-world note above to the Stack section
- `workflows/02_analytics_plan.md` — add Module 8 to Build Order and Output Artifacts sections, following the existing module write-up format
