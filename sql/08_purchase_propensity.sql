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
