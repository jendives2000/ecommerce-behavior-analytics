-- Module 2: Session Analytics
-- Business question: How do users browse before they buy?
-- Table: instant-form-500912-n7.rees46.events (411,709,736 events, Oct 2019 – Apr 2020)
--
-- VERIFIED RESULTS (run 2026-07-02):
--
-- Query 1 — Overall session depth statistics:
--   total_sessions:            89,693,595
--   avg_events_per_session:     4.59
--   median_events:              2
--   p90_events:                11
--   p95_events:                16
--   avg_duration_seconds:  40,415  ← heavily inflated by abandoned tabs; DO NOT use as headline
--   median_duration_seconds:   42
--   purchasing_sessions:    5,449,934   (6.08%)
--   non_purchasing_sessions: 84,243,661
--
--   Key insight: The median session is 42 seconds and 2 events — most users bounce fast.
--   The avg_duration of 40,415s (11+ hours) is entirely driven by sessions left open in
--   browser tabs. Always use median (42s) as the representative duration metric.
--
-- Query 2 — Session event count distribution by bucket:
--   event_bucket      total_sessions  purchasing  non_purchasing  conversion_rate_pct
--   01: 1 event       36,377,146        53,442     36,323,704     0.15%
--   02: 2-5 events    32,911,072     2,518,249     30,392,823     7.65%
--   03: 6-10 events   11,260,308     1,596,659      9,663,649    14.18%
--   04: 11-20 events   6,259,229       872,343      5,386,886    13.94%
--   05: 21-50 events   2,559,907       359,341      2,200,566    14.04%
--   06: 51+ events       325,933        49,900        276,033    15.31%
--
--   Key insight: A "conversion threshold" exists around 6 events. Sessions with 1 event
--   convert at 0.15%; 2-5 events at 7.65%; but 6+ events all plateau at ~14%.
--   40.6% of all sessions (36.4M) are single-event bounces contributing almost no revenue.
--   Sessions with 51+ events convert at 15.31% — barely above the 6-10 bucket (14.18%).
--   More browsing depth beyond 6 events does not materially improve conversion.
--
-- Query 3 — Depth before purchase (at what event # does the purchase occur?):
--   p25_event_rank_at_purchase:   3
--   median_event_rank_at_purchase: 5
--   p75_event_rank_at_purchase:   9
--   p90_event_rank_at_purchase:  17
--   avg_event_rank_at_purchase:   8.23
--   max_event_rank_at_purchase: 1,695  ← extreme outlier, irrelevant to central tendency
--
--   Key insight: The median purchase happens at event #5. 25% of all purchases happen
--   within 3 events. Buyers arrive with intent already formed — they are not long
--   deliberation journeys; they find the product quickly and buy.
--
-- Query 4 — Session profile: converting vs. non-converting:
--   session_type     sessions    avg_events  median_events  avg_views  avg_carts  avg_dur_min  median_dur_min
--   Converting       5,449,934     8.90          6           5.90       1.74       2,982.03      4.38
--   Non-Converting  84,243,661     4.31          2           4.20       0.11         524.25      0.50
--
--   Key insights:
--   - Buyers browse 3× deeper (median 6 vs 2 events) and stay 8.7× longer (4.38 vs 0.50 min)
--   - Converting sessions avg 1.74 carts vs 0.11 for non-converting — cart behavior is the
--     strongest behavioral signal separating buyers from browsers
--   - Avg duration for both groups is severely inflated (2,982 and 524 min) — outlier tabs.
--     Median duration is the only reliable metric: 4.38 min (converting), 0.50 min (non)
--   - The avg_events gap (8.90 vs 4.31) is wider than the median gap (6 vs 2), indicating
--     converting sessions have a heavier right tail — some buyers do very deep browsing

-- ============================================================
-- Query 1: Overall session depth statistics
-- Headline metrics: how deep and how long is a typical session?
-- Unit: one row per user_session, then aggregate across all sessions.
-- ============================================================
WITH session_stats AS (
  SELECT
    user_session,
    COUNT(*)                                                              AS total_events,
    COUNT(CASE WHEN event_type = 'view'     THEN 1 END)                  AS views,
    COUNT(CASE WHEN event_type = 'cart'     THEN 1 END)                  AS carts,
    COUNT(CASE WHEN event_type = 'purchase' THEN 1 END)                  AS purchases,
    TIMESTAMP_DIFF(MAX(event_time), MIN(event_time), SECOND)             AS session_duration_seconds,
    MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END)             AS converted
  FROM `instant-form-500912-n7.rees46.events`
  GROUP BY user_session
)
SELECT
  COUNT(*)                                                          AS total_sessions,
  ROUND(AVG(total_events), 2)                                       AS avg_events_per_session,
  APPROX_QUANTILES(total_events, 100)[OFFSET(50)]                   AS median_events,
  APPROX_QUANTILES(total_events, 100)[OFFSET(90)]                   AS p90_events,
  APPROX_QUANTILES(total_events, 100)[OFFSET(95)]                   AS p95_events,
  ROUND(AVG(session_duration_seconds), 0)                           AS avg_duration_seconds,
  APPROX_QUANTILES(session_duration_seconds, 100)[OFFSET(50)]       AS median_duration_seconds,
  COUNTIF(converted = 1)                                            AS purchasing_sessions,
  COUNTIF(converted = 0)                                            AS non_purchasing_sessions,
  ROUND(COUNTIF(converted = 1) * 100.0 / COUNT(*), 2)              AS purchase_session_pct
FROM session_stats;


-- ============================================================
-- Query 2: Session event count distribution (bucketed)
-- Shape of the distribution: what fraction of sessions are very short?
-- Splits by converted vs. not so we can compare browsing depth.
-- ============================================================
WITH session_stats AS (
  SELECT
    user_session,
    COUNT(*) AS total_events,
    MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS converted
  FROM `instant-form-500912-n7.rees46.events`
  GROUP BY user_session
),
bucketed AS (
  SELECT
    CASE
      WHEN total_events = 1       THEN '01: 1 event'
      WHEN total_events <= 5      THEN '02: 2-5 events'
      WHEN total_events <= 10     THEN '03: 6-10 events'
      WHEN total_events <= 20     THEN '04: 11-20 events'
      WHEN total_events <= 50     THEN '05: 21-50 events'
      ELSE                             '06: 51+ events'
    END AS event_bucket,
    converted,
    COUNT(*) AS session_count
  FROM session_stats
  GROUP BY event_bucket, converted
)
SELECT
  event_bucket,
  SUM(session_count)                                                             AS total_sessions,
  SUM(CASE WHEN converted = 1 THEN session_count ELSE 0 END)                    AS purchasing_sessions,
  SUM(CASE WHEN converted = 0 THEN session_count ELSE 0 END)                    AS non_purchasing_sessions,
  ROUND(
    SUM(CASE WHEN converted = 1 THEN session_count ELSE 0 END) * 100.0 /
    NULLIF(SUM(session_count), 0),
    2
  )                                                                              AS conversion_rate_pct
FROM bucketed
GROUP BY event_bucket
ORDER BY event_bucket;


-- ============================================================
-- Query 3: Session depth before purchase
-- For sessions that include a purchase event: at what event
-- number does the purchase occur?
-- ROW_NUMBER assigns a rank to every event within the session
-- (ordered by event_time). We then read the rank of the
-- purchase event — this tells us how many prior events led up
-- to the purchase decision.
-- Note: if a session has multiple purchase events (multi-item
-- order), this captures the rank of each purchase event.
-- ============================================================
WITH session_events AS (
  SELECT
    user_session,
    event_type,
    event_time,
    ROW_NUMBER() OVER (PARTITION BY user_session ORDER BY event_time) AS event_rank
  FROM `instant-form-500912-n7.rees46.events`
),
purchase_sessions AS (
  SELECT DISTINCT user_session
  FROM `instant-form-500912-n7.rees46.events`
  WHERE event_type = 'purchase'
)
SELECT
  APPROX_QUANTILES(event_rank, 100)[OFFSET(25)]  AS p25_event_rank_at_purchase,
  APPROX_QUANTILES(event_rank, 100)[OFFSET(50)]  AS median_event_rank_at_purchase,
  APPROX_QUANTILES(event_rank, 100)[OFFSET(75)]  AS p75_event_rank_at_purchase,
  APPROX_QUANTILES(event_rank, 100)[OFFSET(90)]  AS p90_event_rank_at_purchase,
  ROUND(AVG(event_rank), 2)                       AS avg_event_rank_at_purchase,
  MAX(event_rank)                                 AS max_event_rank_at_purchase
FROM session_events
JOIN purchase_sessions USING (user_session)
WHERE event_type = 'purchase';


-- ============================================================
-- Query 4: Converting vs. non-converting session profile
-- Side-by-side comparison: do buyers browse differently?
-- Measures: depth (events), composition (views/carts), duration.
-- ============================================================
WITH session_stats AS (
  SELECT
    user_session,
    COUNT(*)                                                         AS total_events,
    COUNT(CASE WHEN event_type = 'view'     THEN 1 END)             AS views,
    COUNT(CASE WHEN event_type = 'cart'     THEN 1 END)             AS carts,
    TIMESTAMP_DIFF(MAX(event_time), MIN(event_time), SECOND)        AS session_duration_seconds,
    MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END)        AS converted
  FROM `instant-form-500912-n7.rees46.events`
  GROUP BY user_session
)
SELECT
  CASE WHEN converted = 1 THEN 'Converting' ELSE 'Non-Converting' END  AS session_type,
  COUNT(*)                                                               AS session_count,
  ROUND(AVG(total_events), 2)                                            AS avg_total_events,
  APPROX_QUANTILES(total_events, 100)[OFFSET(50)]                        AS median_total_events,
  ROUND(AVG(views), 2)                                                   AS avg_views,
  ROUND(AVG(carts), 2)                                                   AS avg_carts,
  ROUND(AVG(session_duration_seconds) / 60.0, 2)                        AS avg_duration_minutes,
  ROUND(
    APPROX_QUANTILES(session_duration_seconds, 100)[OFFSET(50)] / 60.0,
    2
  )                                                                      AS median_duration_minutes
FROM session_stats
GROUP BY converted
ORDER BY converted DESC;
