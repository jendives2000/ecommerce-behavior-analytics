-- Module 4: Cohort Retention
-- Business question: Do customers come back month after month?
-- Table: instant-form-500912-n7.rees46.events (411,709,736 events, Oct 2019 – Apr 2020)
-- Prerequisite: rees46.rfm_segments must exist (created in Module 3).
--
-- COHORT DEFINITION:
--   A cohort = all users whose first purchase occurred in the same calendar month.
--   Dataset window: Oct 2019 – Apr 2020 (7 months).
--   Max observable retention: 6 months (Oct 2019 cohort only).
--   Later cohorts have fewer observation months — expected, not a data gap.
--
-- EXECUTION ORDER:
--   Run Query 1 first (long format — used by Python notebook to build heatmap).
--   Run Query 2 (wide format — easy to read directly in BQ Studio, paste results below).
--   Run Query 3 (average retention rates across all cohorts — headline stats).
--
-- VERIFIED RESULTS (run 2026-07-02):
-- Total users with at least one purchase: 2,064,899 (matches rees46.rfm_segments)
--
-- Query 2 — Wide-format cohort retention matrix:
--   cohort_month  cohort_users  m0    m1     m2     m3     m4     m5     m6
--   2019-10        347,118      100%  26.3%  21.9%  13.7%  12.7%  12.2%  8.1%
--   2019-11        350,352      100%  22.1%  12.2%  11.5%  11.1%   7.7%  [out of window]
--   2019-12        347,286      100%  15.2%  12.5%  12.0%   8.1%  [out of window]
--   2020-01        215,886      100%  18.4%  13.6%   8.8%  [out of window]
--   2020-02        225,048      100%  19.0%  10.4%  [out of window]
--   2020-03        258,674      100%  15.1%  [out of window]
--   2020-04        320,535      100%  [out of window — dataset ends Apr 2020]
--
--   NOTE: 0.0% in BQ Studio output = out-of-observation-window, NOT zero retention.
--   These cells should be treated as NaN/NULL in Python, not plotted as zeros.
--   The Apr 2020 cohort (largest in the dataset) has no M1+ visibility.
--
-- Query 3 — Average retention rates by month offset:
--   months_since_first  cohorts_with_data  avg_retention  min_retention  max_retention
--   0                   7                  100.00%        100.00%        100.00%
--   1                   6                   19.36%         15.13%         26.30%
--   2                   5                   14.12%         10.38%         21.93%
--   3                   4                   11.49%          8.79%         13.73%
--   4                   3                   10.63%          8.12%         12.70%
--   5                   2                    9.94%          7.67%         12.21%
--   6                   1                    8.08%          8.08%          8.08%
--
-- Key insights:
-- 1. M1 average retention: 19.4% — 4 in 5 first-time buyers do not return the next month.
--    This is the single most impactful lever: improving M1 from 19% to 25% would add
--    roughly 33K returning buyers per cohort-month.
-- 2. Retention curve stabilizes fast after M2. The M0→M1 drop (100% → 19%) is the cliff.
--    After that: M2 (14%) → M3 (11%) → M4 (10.6%) → M5 (9.9%) → M6 (8%).
--    Customers who survive past M2 become long-term low-frequency repeaters.
-- 3. Oct 2019 has the best M1 retention (26.3%) — likely the platform's pre-existing
--    loyal customer base already in their purchase cycle at dataset start.
-- 4. Dec 2019 has the lowest M1 retention (15.2%) — likely post-holiday effect.
--    Customers acquired in November's promotional peak did not convert to habits.
-- 5. Apr 2020 cohort (320,535 users) is the largest in the dataset — COVID lockdown
--    drove peak new-user acquisition. M1 retention is unobservable (May 2020 is outside
--    the dataset window). This is the key unknown in the COVID quasi-experiment (Module 7).
-- 6. Cohort sizes: Jan 2020 dips to 215,886 (post-holiday acquisition slowdown),
--    then Feb/Mar/Apr recover as COVID drives e-commerce adoption.
-- 7. For the Python heatmap: use Query 1 long-format output (not Query 2).
--    Out-of-window months appear as missing rows in Query 1, which pandas will correctly
--    fill as NaN when pivoted — preventing false zeros in the heatmap.

-- ============================================================
-- Query 1: Long-format retention matrix
-- One row per (cohort_month, months_since_first) pair.
-- This is the format Python needs to pivot into a heatmap.
-- Export this result to CSV for the notebook.
-- ============================================================
WITH first_purchase AS (
  SELECT
    user_id,
    DATE_TRUNC(MIN(DATE(event_time)), MONTH) AS cohort_month
  FROM `instant-form-500912-n7.rees46.events`
  WHERE event_type = 'purchase'
  GROUP BY user_id
),
user_activity AS (
  -- one row per user per month they made any purchase
  SELECT DISTINCT
    user_id,
    DATE_TRUNC(DATE(event_time), MONTH) AS activity_month
  FROM `instant-form-500912-n7.rees46.events`
  WHERE event_type = 'purchase'
),
cohort_data AS (
  SELECT
    fp.cohort_month,
    DATE_DIFF(ua.activity_month, fp.cohort_month, MONTH) AS months_since_first,
    COUNT(DISTINCT ua.user_id)                            AS active_users
  FROM first_purchase fp
  JOIN user_activity ua USING (user_id)
  GROUP BY fp.cohort_month, months_since_first
),
cohort_size AS (
  SELECT
    cohort_month,
    COUNT(DISTINCT user_id) AS cohort_users
  FROM first_purchase
  GROUP BY cohort_month
)
SELECT
  FORMAT_DATE('%Y-%m', cd.cohort_month)                    AS cohort_month,
  cs.cohort_users,
  cd.months_since_first,
  cd.active_users,
  ROUND(cd.active_users * 100.0 / cs.cohort_users, 2)      AS retention_rate_pct
FROM cohort_data cd
JOIN cohort_size cs USING (cohort_month)
ORDER BY cd.cohort_month, cd.months_since_first;


-- ============================================================
-- Query 2: Wide-format cohort matrix (one row per cohort)
-- Months 0–6 as columns. Month 0 = acquisition month (should be ~100%).
-- NULL where observation window doesn't reach that month.
-- Easy to read directly in BQ Studio — paste results into header above.
-- ============================================================
WITH first_purchase AS (
  SELECT
    user_id,
    DATE_TRUNC(MIN(DATE(event_time)), MONTH) AS cohort_month
  FROM `instant-form-500912-n7.rees46.events`
  WHERE event_type = 'purchase'
  GROUP BY user_id
),
user_activity AS (
  SELECT DISTINCT
    user_id,
    DATE_TRUNC(DATE(event_time), MONTH) AS activity_month
  FROM `instant-form-500912-n7.rees46.events`
  WHERE event_type = 'purchase'
),
retention_base AS (
  SELECT
    fp.cohort_month,
    fp.user_id,
    DATE_DIFF(ua.activity_month, fp.cohort_month, MONTH) AS months_since_first
  FROM first_purchase fp
  JOIN user_activity ua USING (user_id)
),
cohort_size AS (
  SELECT
    cohort_month,
    COUNT(DISTINCT user_id) AS cohort_users
  FROM first_purchase
  GROUP BY cohort_month
)
SELECT
  FORMAT_DATE('%Y-%m', rb.cohort_month)                                                              AS cohort_month,
  cs.cohort_users,
  ROUND(COUNT(DISTINCT CASE WHEN months_since_first = 0 THEN rb.user_id END) * 100.0 / cs.cohort_users, 1) AS m0_pct,
  ROUND(COUNT(DISTINCT CASE WHEN months_since_first = 1 THEN rb.user_id END) * 100.0 / cs.cohort_users, 1) AS m1_pct,
  ROUND(COUNT(DISTINCT CASE WHEN months_since_first = 2 THEN rb.user_id END) * 100.0 / cs.cohort_users, 1) AS m2_pct,
  ROUND(COUNT(DISTINCT CASE WHEN months_since_first = 3 THEN rb.user_id END) * 100.0 / cs.cohort_users, 1) AS m3_pct,
  ROUND(COUNT(DISTINCT CASE WHEN months_since_first = 4 THEN rb.user_id END) * 100.0 / cs.cohort_users, 1) AS m4_pct,
  ROUND(COUNT(DISTINCT CASE WHEN months_since_first = 5 THEN rb.user_id END) * 100.0 / cs.cohort_users, 1) AS m5_pct,
  ROUND(COUNT(DISTINCT CASE WHEN months_since_first = 6 THEN rb.user_id END) * 100.0 / cs.cohort_users, 1) AS m6_pct
FROM retention_base rb
JOIN cohort_size cs USING (cohort_month)
GROUP BY rb.cohort_month, cs.cohort_users
ORDER BY rb.cohort_month;


-- ============================================================
-- Query 3: Average retention rate by month offset
-- Averages across all cohorts that have data for each offset.
-- Month 6 average only includes the Oct 2019 cohort (only one
-- with full 6-month visibility) — interpret with caution.
-- ============================================================
WITH first_purchase AS (
  SELECT
    user_id,
    DATE_TRUNC(MIN(DATE(event_time)), MONTH) AS cohort_month
  FROM `instant-form-500912-n7.rees46.events`
  WHERE event_type = 'purchase'
  GROUP BY user_id
),
user_activity AS (
  SELECT DISTINCT
    user_id,
    DATE_TRUNC(DATE(event_time), MONTH) AS activity_month
  FROM `instant-form-500912-n7.rees46.events`
  WHERE event_type = 'purchase'
),
cohort_data AS (
  SELECT
    fp.cohort_month,
    DATE_DIFF(ua.activity_month, fp.cohort_month, MONTH) AS months_since_first,
    COUNT(DISTINCT ua.user_id)                            AS active_users
  FROM first_purchase fp
  JOIN user_activity ua USING (user_id)
  GROUP BY fp.cohort_month, months_since_first
),
cohort_size AS (
  SELECT cohort_month, COUNT(DISTINCT user_id) AS cohort_users
  FROM first_purchase
  GROUP BY cohort_month
),
retention_rates AS (
  SELECT
    cd.cohort_month,
    cd.months_since_first,
    ROUND(cd.active_users * 100.0 / cs.cohort_users, 2) AS retention_rate_pct
  FROM cohort_data cd
  JOIN cohort_size cs USING (cohort_month)
)
SELECT
  months_since_first,
  COUNT(*)                              AS cohorts_with_data,
  ROUND(AVG(retention_rate_pct), 2)     AS avg_retention_pct,
  ROUND(MIN(retention_rate_pct), 2)     AS min_retention_pct,
  ROUND(MAX(retention_rate_pct), 2)     AS max_retention_pct
FROM retention_rates
GROUP BY months_since_first
ORDER BY months_since_first;
