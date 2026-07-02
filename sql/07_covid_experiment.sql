-- Module 7: COVID Quasi-Experiment
-- Business question: Did COVID-19 onset measurably change purchasing behavior?
-- Table: instant-form-500912-n7.rees46.events (411,709,736 events, Oct 2019 – Apr 2020)
--
-- NATURAL EXPERIMENT SETUP:
--   Kazakhstan confirmed its first COVID-19 case on March 13, 2020.
--   A national lockdown began on March 16, 2020. This created a sharp, externally-imposed
--   behavioral shock — the kind of clean treatment boundary that makes causal inference
--   defensible. This is a quasi-experiment (not a randomized trial): we observe the
--   same platform before and after an exogenous event.
--
-- PERIOD DEFINITIONS:
--   Pre-COVID:   Oct 1, 2019 – Mar 12, 2020 (163 days after exclusion)
--   Transition:  Mar 13–15, 2020 — EXCLUDED from both groups (ambiguous treatment)
--   COVID onset: Mar 16, 2020 – Apr 30, 2020 (46 days)
--
-- DATA QUALITY EXCLUSIONS APPLIED IN EVERY QUERY:
--   1. DATE(event_time) != '2020-02-27'            — confirmed logging gap (z = -18.84)
--   2. DATE(event_time) NOT BETWEEN '2020-03-13'
--      AND '2020-03-15'                            — transition window, excluded from both periods
--
-- CATEGORY ANALYSIS NOTE (Query 3):
--   A platform taxonomy event on Dec 2, 2019 caused Apple/Samsung/Xiaomi to be
--   reclassified from 'electronics' to 'construction'. Using Oct 2019 as the pre-COVID
--   baseline for category-level analysis would contaminate the comparison.
--   Query 3 therefore uses Jan 1, 2020 – Mar 12, 2020 as its pre-COVID window
--   (post-taxonomy-fix, 71 days) vs Mar 16 – Apr 30, 2020 (46 days).
--   Queries 1, 2, 4, and 5 are not category-level and use the full Oct 2019 baseline.
--
-- PERIOD LENGTH CAVEAT:
--   Pre-COVID = 163 days; COVID onset = 46 days. Raw volume totals are not comparable.
--   All cross-period comparisons use rates (conversion %, session conversion %, share %)
--   or per-unit averages (AOV, avg events/session). The Python z-test uses proportions,
--   which account for sample size differences automatically.
--
-- EXECUTION ORDER:
--   Query 1 — Conversion funnel + AOV: pre vs COVID (z-test inputs + headline metrics)
--   Query 2 — Weekly trend: conversion rate week-by-week (feeds notebook time series)
--   Query 3 — Category revenue mix shift (Jan 2020 baseline — avoids taxonomy noise)
--   Query 4 — Session behavior shift (depth, products viewed, session purchase rate)
--   Query 5 — New vs returning buyer mix (did COVID bring new users or activate existing?)
--
-- VERIFIED RESULTS (run 2026-07-02):
--
-- Query 1 — Conversion funnel + AOV: Pre-COVID vs COVID onset
--   period        views       carts     purchases  total_revenue  AOV       v→pur%  cart→pur%  s_conv%  sessions    pur_sessions
--   Pre-COVID   297,370,311  14,356,487  5,339,676  1,641,912,463  307.49  1.7956   37.19    5.8356   72,286,478   4,218,364
--   COVID onset  83,604,585   4,458,709  1,375,611    373,706,635  271.67  1.6454   30.85    6.8867   16,262,389   1,119,942
--
--   PARADOX: view_to_purchase DROPPED (1.80% → 1.65%) while session_conversion INCREASED
--   (5.84% → 6.89%). Resolution: people browsed MORE per session during lockdown (Q4 shows
--   avg products viewed: 2.79 → 3.41, +22%). More views per session dilutes the view-level
--   rate even though a higher share of sessions ended in a purchase.
--   Session conversion is the correct metric for the z-test — it measures buyer intent.
--
-- Query 2 — Weekly trend highlights (full 28-week series in CSV):
--   Nov 11, 2019:  26.2M views — traffic spike, likely flash sale (Black Friday region)
--   Feb 10, 2020:  527,825 purchases (3.65% v→pur) — Valentine's Day promo anomaly
--   Mar 9  (split): week straddles Pre-COVID / Transition boundary
--   Mar 16, 2020:  COVID lockdown week 1 — session_conv immediately jumps to 6.73%
--   Mar 23, 2020:  session_conv 7.59% (lockdown deepens, people shift to online)
--   Mar 30, 2020:  session_conv 7.97% (peak conversion week of entire dataset)
--   Apr 20, 2020:  session_conv drops to 5.12% (possible lockdown fatigue / restrictions ease)
--
-- Query 3 — Category revenue mix shift (Jan 2020 baseline):
--   category                    pre_share%  covid_share%  direction
--   DIY / Home Improvement *     69.02       57.32         ↓ (taxonomy artifact — not real DIY)
--   Appliances                   11.06       16.45         ↑ home appliance buying during lockdown
--   Electronics                   7.19       11.72         ↑ significant gain
--   apparel                       3.44        4.69         ↑ moderate gain
--   Sports & Outdoor              2.84        2.01         ↓ gyms closed, outdoor activity restricted
--   Unknown / No Category         2.38        4.43         ↑ (may absorb misclassified items)
--   Computers & Peripherals       1.54        1.11         ↓ slight decline
--   Furniture & Home              1.25        1.13         ≈ stable
--
--   Note: DIY* share DROP during COVID is partly because Appliances/Electronics grew — the
--   misclassified smartphone bucket was already dominant and its share compressed as other
--   categories accelerated. Interpret all category shifts with the taxonomy caveat in mind.
--
-- Query 4 — Session behavior shift:
--   period        sessions     avg_events/s  avg_products  pur_sessions  s_pur_rate%  avg_s_revenue
--   Pre-COVID    72,286,479     4.39          2.79         4,218,364      5.84         389.23
--   COVID onset  16,262,390     5.50          3.41         1,119,943      6.89         333.68
--
--   Sessions got 25% longer (4.39 → 5.50 events) and 22% broader (2.79 → 3.41 products).
--   More sessions converted to purchases (+18% relative rate).
--   But each purchasing session generated 14% less revenue ($389 → $334).
--   Interpretation: lockdown drove higher browsing engagement and purchase intent,
--   but economic uncertainty pushed buyers toward cheaper items.
--
-- Query 5 — New vs returning buyer mix:
--   period        buyer_type      unique_buyers  total_pur   AOV
--   Pre-COVID     New buyer       1,606,920      2,221,822   289.28
--   Pre-COVID     Returning       633,585        3,117,854   320.47
--   COVID onset   New buyer       424,885          583,170   256.01
--   COVID onset   Returning       305,779          792,441   283.19
--
--   Daily rate comparison (normalised for period length):
--     New buyers/day:      pre=9,858  covid=9,236  → roughly flat (-6%)
--     Returning buyers/day: pre=3,887  covid=6,648  → +71% surge during lockdown
--   The COVID boost was driven by EXISTING customers returning more often,
--   not a wave of new buyers. New acquisition was nearly unchanged.
--   AOV fell in both groups (~11%) regardless of buyer type — the whole basket got cheaper.
--
-- Key insights:
-- 1. Session conversion INCREASED during COVID: 5.84% → 6.89% (+18% relative, ~+1.05 pp).
--    Given sample sizes (72M pre, 16M COVID sessions), the z-test will almost certainly
--    confirm statistical significance. The platform became more efficient at converting
--    sessions into purchases the moment lockdown began.
-- 2. The view-to-purchase rate DECLINED (1.80% → 1.65%) — an apparent contradiction
--    resolved by browsing depth: people viewed 22% more products per session during lockdown.
--    More browsing per session → more views per purchase → lower view-level rate.
--    This is a methodological lesson: choose the right denominator for conversion analysis.
-- 3. AOV fell 11.7% ($307.49 → $271.67). Economic uncertainty drove smaller, cheaper baskets.
--    This held true for both new and returning buyers — behavioral not demographic.
-- 4. Lockdown activated existing customers: returning buyer daily rate surged +71%.
--    New buyer acquisition was nearly unchanged. COVID was a retention catalyst, not an
--    acquisition driver. This has direct implications for CRM and loyalty strategy.
-- 5. Weekly trend reveals the conversion peak was March 30, 2020 (session_conv 7.97%) —
--    two weeks into the lockdown. By late April it fell back to 5.12%, suggesting
--    lockdown e-commerce adoption peaked quickly then stabilised or reversed.
-- 6. Category winners during COVID: Appliances (+5.4 pp share) and Electronics (+4.5 pp).
--    Category losers: Sports & Outdoor (-0.8 pp). Home investment patterns dominate.


-- ============================================================
-- Query 1: Conversion funnel + AOV — Pre-COVID vs COVID onset
-- Produces two rows (one per period) with:
--   - Event-level funnel metrics (views → carts → purchases)
--   - Session-level conversion rate (z-test denominator: sessions with purchase / all sessions)
--   - AOV (avg_order_value) for pre vs during comparison
-- NOTE: total_sessions and purchase_sessions feed directly into the Python z-test.
-- ============================================================
WITH period_assignment AS (
  SELECT
    event_type,
    price,
    user_session,
    CASE
      WHEN DATE(event_time) <= '2020-03-12'
       AND DATE(event_time) != '2020-02-27'  THEN 'Pre-COVID'
      WHEN DATE(event_time) >= '2020-03-16'  THEN 'COVID onset'
      ELSE NULL
    END AS period
  FROM `instant-form-500912-n7.rees46.events`
  WHERE DATE(event_time) NOT BETWEEN '2020-03-13' AND '2020-03-15'
    AND DATE(event_time) != '2020-02-27'
),
event_metrics AS (
  SELECT
    period,
    COUNT(CASE WHEN event_type = 'view'     THEN 1 END)          AS total_views,
    COUNT(CASE WHEN event_type = 'cart'     THEN 1 END)          AS total_carts,
    COUNT(CASE WHEN event_type = 'purchase' THEN 1 END)          AS total_purchases,
    ROUND(SUM(CASE WHEN event_type = 'purchase' AND price > 0
                   THEN price END), 2)                           AS total_revenue,
    ROUND(AVG(CASE WHEN event_type = 'purchase' AND price > 0
                   THEN price END), 2)                           AS avg_order_value
  FROM period_assignment
  WHERE period IS NOT NULL
  GROUP BY period
),
session_metrics AS (
  SELECT
    period,
    COUNT(DISTINCT user_session)                                              AS total_sessions,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_session END)  AS purchase_sessions
  FROM period_assignment
  WHERE period IS NOT NULL
  GROUP BY period
)
SELECT
  em.period,
  em.total_views,
  em.total_carts,
  em.total_purchases,
  em.total_revenue,
  em.avg_order_value,
  ROUND(em.total_carts     * 100.0 / NULLIF(em.total_views, 0), 4)   AS view_to_cart_pct,
  ROUND(em.total_purchases * 100.0 / NULLIF(em.total_carts, 0), 4)   AS cart_to_purchase_pct,
  ROUND(em.total_purchases * 100.0 / NULLIF(em.total_views, 0), 4)   AS view_to_purchase_pct,
  sm.total_sessions,
  sm.purchase_sessions,
  ROUND(sm.purchase_sessions * 100.0 / NULLIF(sm.total_sessions, 0), 4) AS session_conversion_pct
FROM event_metrics em
JOIN session_metrics sm USING (period)
ORDER BY em.period DESC;


-- ============================================================
-- Query 2: Weekly conversion rate trend
-- One row per week. Includes the transition window (labeled separately)
-- so the chart shows the full picture — but transition weeks are
-- excluded from the z-test in Query 1.
-- Export to CSV for notebook time-series visualization.
-- ============================================================
WITH week_events AS (
  SELECT
    DATE_TRUNC(DATE(event_time), WEEK(MONDAY)) AS week_start,
    event_type,
    user_session,
    CASE
      WHEN DATE(event_time) <= '2020-03-12'
       AND DATE(event_time) != '2020-02-27'  THEN 'Pre-COVID'
      WHEN DATE(event_time) BETWEEN '2020-03-13' AND '2020-03-15' THEN 'Transition'
      WHEN DATE(event_time) >= '2020-03-16'  THEN 'COVID onset'
    END AS period
  FROM `instant-form-500912-n7.rees46.events`
  WHERE DATE(event_time) != '2020-02-27'
)
SELECT
  week_start,
  period,
  COUNT(CASE WHEN event_type = 'view'     THEN 1 END)          AS weekly_views,
  COUNT(CASE WHEN event_type = 'purchase' THEN 1 END)          AS weekly_purchases,
  COUNT(DISTINCT user_session)                                  AS weekly_sessions,
  COUNT(DISTINCT CASE WHEN event_type = 'purchase'
                      THEN user_session END)                   AS purchase_sessions,
  ROUND(COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) * 100.0 /
        NULLIF(COUNT(CASE WHEN event_type = 'view' THEN 1 END), 0), 4) AS view_to_purchase_pct,
  ROUND(COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_session END) * 100.0 /
        NULLIF(COUNT(DISTINCT user_session), 0), 4)            AS session_conversion_pct
FROM week_events
GROUP BY week_start, period
ORDER BY week_start;


-- ============================================================
-- Query 3: Category revenue mix shift
-- Pre-COVID window: Jan 1 – Mar 12, 2020 (71 days, post-taxonomy-fix).
-- COVID onset: Mar 16 – Apr 30, 2020 (46 days).
-- Comparison is revenue share %, not absolute revenue (periods differ in length).
-- 'construction' label retained with anomaly note — do not exclude, just interpret with care.
-- ============================================================
WITH period_purchases AS (
  SELECT
    SPLIT(COALESCE(category_code, 'unknown'), '.')[OFFSET(0)] AS raw_category,
    price,
    CASE
      WHEN DATE(event_time) BETWEEN '2020-01-01' AND '2020-03-12' THEN 'Pre-COVID (Jan–Mar 12)'
      WHEN DATE(event_time) >= '2020-03-16'                        THEN 'COVID onset (Mar 16–Apr 30)'
      ELSE NULL
    END AS period
  FROM `instant-form-500912-n7.rees46.events`
  WHERE event_type = 'purchase'
    AND price > 0
    AND DATE(event_time) != '2020-02-27'
    AND DATE(event_time) NOT BETWEEN '2020-03-13' AND '2020-03-15'
),
cat_agg AS (
  -- CTE named 'cat_agg' (not 'category_revenue') to avoid BQ name collision
  -- with the column alias 'category_revenue' inside this same CTE.
  SELECT
    period,
    CASE raw_category
      WHEN 'electronics'  THEN 'Electronics'
      WHEN 'appliances'   THEN 'Appliances'
      WHEN 'computers'    THEN 'Computers & Peripherals'
      WHEN 'construction' THEN 'DIY / Home Improvement *'
      WHEN 'country_yard' THEN 'Garden & Dacha'
      WHEN 'sport'        THEN 'Sports & Outdoor'
      WHEN 'auto'         THEN 'Automotive'
      WHEN 'furniture'    THEN 'Furniture & Home'
      WHEN 'kids'         THEN 'Kids & Toys'
      WHEN 'medicine'     THEN 'Health & Medicine'
      WHEN 'stationery'   THEN 'Stationery & Office'
      WHEN 'unknown'      THEN 'Unknown / No Category'
      ELSE raw_category
    END                    AS category,
    ROUND(SUM(price), 2)   AS category_revenue,
    COUNT(*)               AS purchase_count
  FROM period_purchases
  WHERE period IS NOT NULL
  GROUP BY period, raw_category
),
period_totals AS (
  SELECT period, SUM(category_revenue) AS period_total
  FROM cat_agg
  GROUP BY period
)
SELECT
  ca.period,
  ca.category,
  ca.category_revenue,
  ca.purchase_count,
  ROUND(ca.category_revenue * 100.0 / NULLIF(pt.period_total, 0), 2) AS revenue_share_pct
FROM cat_agg ca
JOIN period_totals pt USING (period)
ORDER BY ca.period, ca.category_revenue DESC;
-- * 'DIY / Home Improvement' = raw category_code 'construction'.
--   Contains Apple/Samsung/Xiaomi smartphones due to taxonomy error (see README Data Quality).
--   Revenue share for this category should be interpreted with caution.


-- ============================================================
-- Query 4: Session behavior shift
-- Measures whether browsing depth changed — not just purchase rate.
-- avg_events_per_session: how many actions per session on average
-- avg_products_viewed: distinct products per session
-- session_purchase_rate_pct: % of sessions that resulted in a purchase
-- avg_session_revenue: average revenue for sessions that had a purchase
-- ============================================================
WITH period_events AS (
  SELECT
    user_session,
    event_type,
    price,
    product_id,
    CASE
      WHEN DATE(event_time) <= '2020-03-12'
       AND DATE(event_time) != '2020-02-27'  THEN 'Pre-COVID'
      WHEN DATE(event_time) >= '2020-03-16'  THEN 'COVID onset'
      ELSE NULL
    END AS period
  FROM `instant-form-500912-n7.rees46.events`
  WHERE DATE(event_time) NOT BETWEEN '2020-03-13' AND '2020-03-15'
    AND DATE(event_time) != '2020-02-27'
),
session_agg AS (
  SELECT
    period,
    user_session,
    COUNT(*)                                                               AS events_in_session,
    COUNT(DISTINCT product_id)                                             AS distinct_products,
    MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END)              AS has_purchase,
    ROUND(SUM(CASE WHEN event_type = 'purchase' AND price > 0
                   THEN price END), 2)                                    AS session_revenue
  FROM period_events
  WHERE period IS NOT NULL
  GROUP BY period, user_session
)
SELECT
  period,
  COUNT(*)                                                                AS total_sessions,
  ROUND(AVG(events_in_session), 2)                                       AS avg_events_per_session,
  ROUND(AVG(distinct_products), 2)                                       AS avg_products_viewed,
  SUM(has_purchase)                                                       AS purchase_sessions,
  ROUND(SUM(has_purchase) * 100.0 / NULLIF(COUNT(*), 0), 4)             AS session_purchase_rate_pct,
  ROUND(AVG(CASE WHEN has_purchase = 1 THEN session_revenue END), 2)    AS avg_session_revenue
FROM session_agg
WHERE period IS NOT NULL
GROUP BY period
ORDER BY period DESC;


-- ============================================================
-- Query 5: New vs returning buyer mix
-- Classifies each buyer in each period as:
--   New buyer    — this period contains their very first purchase ever
--   Returning    — they had purchased before this period
-- Tests whether COVID brought new users to e-commerce or activated dormant ones.
-- ============================================================
WITH first_purchase_ever AS (
  SELECT
    user_id,
    MIN(DATE(event_time)) AS first_purchase_date
  FROM `instant-form-500912-n7.rees46.events`
  WHERE event_type = 'purchase'
  GROUP BY user_id
),
period_buyers AS (
  SELECT
    e.user_id,
    e.price,
    CASE
      WHEN DATE(e.event_time) <= '2020-03-12'
       AND DATE(e.event_time) != '2020-02-27'  THEN 'Pre-COVID'
      WHEN DATE(e.event_time) >= '2020-03-16'  THEN 'COVID onset'
      ELSE NULL
    END AS period,
    CASE
      WHEN DATE(e.event_time) = fp.first_purchase_date THEN 'New buyer'
      ELSE 'Returning buyer'
    END AS buyer_type
  FROM `instant-form-500912-n7.rees46.events` e
  JOIN first_purchase_ever fp USING (user_id)
  WHERE e.event_type = 'purchase'
    AND e.price > 0
    AND DATE(e.event_time) NOT BETWEEN '2020-03-13' AND '2020-03-15'
    AND DATE(e.event_time) != '2020-02-27'
)
SELECT
  period,
  buyer_type,
  COUNT(DISTINCT user_id)  AS unique_buyers,
  COUNT(*)                 AS total_purchases,
  ROUND(SUM(price), 2)     AS total_revenue,
  ROUND(AVG(price), 2)     AS avg_order_value
FROM period_buyers
WHERE period IS NOT NULL
GROUP BY period, buyer_type
ORDER BY period DESC, buyer_type;
