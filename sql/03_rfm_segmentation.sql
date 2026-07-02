-- Module 3: RFM Segmentation
-- Business question: Who are the best customers?
-- Table: instant-form-500912-n7.rees46.events (411,709,736 events, Oct 2019 – Apr 2020)
--
-- RFM SCORING CONVENTION (5 = best on all three dimensions):
--   R score 5 = purchased very recently    (recency_days low → high NTILE → score 5)
--   F score 5 = purchases most frequently  (frequency high → high NTILE → score 5)
--   M score 5 = highest total spend        (monetary high → high NTILE → score 5)
--
-- EXECUTION ORDER:
--   Step 1 — Run Query 1 (SELECT only) to preview RFM scores before writing anything.
--   Step 2 — Run the CREATE TABLE block to persist as rees46.rfm_segments.
--             Module 4 (Cohort Retention) requires this table.
--   Step 3 — Run Query 2 (segment distribution) once the table exists.
--   Step 4 — Run Query 3 (monetary percentiles by segment) for Python notebook export.
--
-- VERIFIED RESULTS (run 2026-07-02):
-- Total users with at least one purchase: 2,064,899
-- rfm_segments table created: instant-form-500912-n7.rees46.rfm_segments
--
-- Query 2 — Segment distribution:
--   segment                 users    pct_users  avg_recency  avg_freq  avg_monetary  total_revenue  pct_revenue
--   Champion               273,211   13.23%        27.8       9.24     3,117.85     851,832,084    41.40%
--   Loyal                  546,258   26.45%        54.7       3.69       966.62     528,025,860    25.66%
--   At Risk                419,470   20.31%       152.6       3.53     1,087.71     456,261,010    22.18%
--   Others                 426,170   20.64%       130.2       1.00       276.00     117,621,301     5.72%
--   Recent but Infrequent  289,189   14.00%        27.3       1.00       253.60      73,337,237     3.56%
--   Lost                   110,601    5.36%       182.4       1.00       274.59      30,369,732     1.48%
--
--   Key insights:
--   - Champions (13.23% of users) generate 41.4% of all revenue. Classic Pareto — and extreme.
--   - At Risk is the highest-value win-back target: 419K users, 456M revenue, avg 152 days
--     quiet after averaging 3.53 purchases. Reactivating even 20% of them is high ROI.
--   - Loyal is the backbone: largest segment (26.45%), generates 25.66% of revenue.
--     Close to Champions in revenue weight — converting some Loyal → Champion is achievable.
--   - Recent but Infrequent (289K users) bought within 27.3 days avg but only once.
--     Second-purchase conversion is the single highest-leverage growth action for this group.
--   - Others + Lost + Recent but Infrequent combined: ~40% of users, only 10.76% of revenue.
--     Low priority for retention spend; focus budget on the top three segments.
--
-- Query 3 — Monetary percentiles by segment:
--   segment                 users    P25       median    P75       P90       avg       max
--   Champion               273,211   792.74   1,384.98  2,869.93  6,210.49  3,117.85  790,120.94
--   At Risk                419,470   211.68     465.34  1,081.29  2,366.60  1,087.71  473,119.39
--   Loyal                  546,258   180.07     361.06    830.60  2,002.10    966.62  474,648.46
--   Others                 426,170    82.33     170.15    311.08    733.30    276.00    2,574.07
--   Lost                   110,601    77.22     169.35    308.86    719.68    274.59    2,574.07
--   Recent but Infrequent  289,189    64.33     166.77    302.08    591.78    253.60    2,574.07
--
--   Key insights:
--   - Champions have a heavy right tail: median 1,385 vs avg 3,118 vs max 790,121.
--     A small number of ultra-high spenders dominate the average. P90 at 6,210 means
--     10% of Champions spent over 6K — use median as the representative metric in dashboards.
--   - At Risk avg (1,087) exceeds Loyal avg (966) — At Risk users were high spenders before
--     going quiet. They are not just frequent; they were also big-ticket buyers.
--   - Note on currency: prices in source data are likely KZT (Kazakhstani tenge) or USD.
--     Domain context does not confirm denomination. Treat monetary as relative ranking,
--     not absolute currency figures, unless source currency is confirmed.

-- ============================================================
-- Query 1 (PREVIEW): Compute RFM scores per user
-- Run this first to inspect the output before persisting.
-- Reference date: 2020-05-01 (day after last event in dataset)
-- Only users with at least one purchase event are included.
-- ============================================================
WITH purchase_events AS (
  SELECT
    user_id,
    event_time,
    price
  FROM `instant-form-500912-n7.rees46.events`
  WHERE event_type = 'purchase'
    AND price > 0
),
rfm_raw AS (
  SELECT
    user_id,
    DATE_DIFF(DATE '2020-05-01', MAX(DATE(event_time)), DAY)  AS recency_days,
    COUNT(*)                                                   AS frequency,
    SUM(price)                                                 AS monetary
  FROM purchase_events
  GROUP BY user_id
),
rfm_scored AS (
  SELECT
    user_id,
    recency_days,
    frequency,
    monetary,
    -- 5 = best on all three dimensions
    NTILE(5) OVER (ORDER BY recency_days DESC)  AS r_score,  -- most recent buyers get score 5
    NTILE(5) OVER (ORDER BY frequency ASC)      AS f_score,  -- most frequent buyers get score 5
    NTILE(5) OVER (ORDER BY monetary ASC)       AS m_score   -- highest spenders get score 5
  FROM rfm_raw
)
SELECT
  user_id,
  recency_days,
  frequency,
  ROUND(monetary, 2)           AS monetary,
  r_score,
  f_score,
  m_score,
  r_score + f_score + m_score  AS rfm_total,
  CASE
    WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champion'
    WHEN r_score >= 3 AND f_score >= 3                  THEN 'Loyal'
    WHEN r_score >= 4 AND f_score <= 2                  THEN 'Recent but Infrequent'
    WHEN r_score <= 2 AND f_score >= 3                  THEN 'At Risk'
    WHEN r_score = 1  AND f_score = 1                   THEN 'Lost'
    ELSE                                                     'Others'
  END AS segment
FROM rfm_scored
ORDER BY rfm_total DESC
LIMIT 1000;  -- preview only


-- ============================================================
-- Step 2: Persist RFM scores as a BigQuery table
-- Required by Module 4. Run AFTER previewing Query 1.
-- Remove the LIMIT clause — this writes all users.
-- ============================================================
CREATE OR REPLACE TABLE `instant-form-500912-n7.rees46.rfm_segments` AS
WITH purchase_events AS (
  SELECT
    user_id,
    event_time,
    price
  FROM `instant-form-500912-n7.rees46.events`
  WHERE event_type = 'purchase'
    AND price > 0
),
rfm_raw AS (
  SELECT
    user_id,
    DATE_DIFF(DATE '2020-05-01', MAX(DATE(event_time)), DAY)  AS recency_days,
    COUNT(*)                                                   AS frequency,
    SUM(price)                                                 AS monetary
  FROM purchase_events
  GROUP BY user_id
),
rfm_scored AS (
  SELECT
    user_id,
    recency_days,
    frequency,
    monetary,
    NTILE(5) OVER (ORDER BY recency_days DESC)  AS r_score,
    NTILE(5) OVER (ORDER BY frequency ASC)      AS f_score,
    NTILE(5) OVER (ORDER BY monetary ASC)       AS m_score
  FROM rfm_raw
)
SELECT
  user_id,
  recency_days,
  frequency,
  ROUND(monetary, 2)           AS monetary,
  r_score,
  f_score,
  m_score,
  r_score + f_score + m_score  AS rfm_total,
  CASE
    WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champion'
    WHEN r_score >= 3 AND f_score >= 3                  THEN 'Loyal'
    WHEN r_score >= 4 AND f_score <= 2                  THEN 'Recent but Infrequent'
    WHEN r_score <= 2 AND f_score >= 3                  THEN 'At Risk'
    WHEN r_score = 1  AND f_score = 1                   THEN 'Lost'
    ELSE                                                     'Others'
  END AS segment
FROM rfm_scored;


-- ============================================================
-- Query 2: Segment distribution summary
-- Run AFTER Step 2 (table must exist).
-- Shows user count and average R/F/M per segment.
-- ============================================================
SELECT
  segment,
  COUNT(*)                         AS user_count,
  ROUND(COUNT(*) * 100.0 /
    SUM(COUNT(*)) OVER(), 2)       AS pct_of_users,
  ROUND(AVG(recency_days), 1)      AS avg_recency_days,
  ROUND(AVG(frequency), 2)         AS avg_frequency,
  ROUND(AVG(monetary), 2)          AS avg_monetary,
  ROUND(SUM(monetary), 2)          AS total_revenue,
  ROUND(SUM(monetary) * 100.0 /
    SUM(SUM(monetary)) OVER(), 2)  AS pct_of_revenue
FROM `instant-form-500912-n7.rees46.rfm_segments`
GROUP BY segment
ORDER BY avg_monetary DESC;


-- ============================================================
-- Query 3: Monetary distribution by segment (for Python box plot)
-- Percentiles P25 / median / P75 / P90 and mean per segment.
-- Export this result for the notebook visualization.
-- ============================================================
SELECT
  segment,
  COUNT(*)                                                         AS user_count,
  ROUND(APPROX_QUANTILES(monetary, 100)[OFFSET(25)],  2)          AS p25_monetary,
  ROUND(APPROX_QUANTILES(monetary, 100)[OFFSET(50)],  2)          AS median_monetary,
  ROUND(APPROX_QUANTILES(monetary, 100)[OFFSET(75)],  2)          AS p75_monetary,
  ROUND(APPROX_QUANTILES(monetary, 100)[OFFSET(90)],  2)          AS p90_monetary,
  ROUND(AVG(monetary), 2)                                          AS avg_monetary,
  ROUND(MAX(monetary), 2)                                          AS max_monetary
FROM `instant-form-500912-n7.rees46.rfm_segments`
GROUP BY segment
ORDER BY median_monetary DESC;
