-- Module 1: Funnel Analysis
-- Business question: What is the conversion rate from view → cart → purchase,
-- and where does it break down?
-- Table: instant-form-500912-n7.rees46.events (411,709,736 events, Oct 2019 – Apr 2020)
--
-- SCOPE NOTE: This dataset has no raw site-visit event — "view" means a product-detail-page
-- view, not a homepage/search visit. This conversion rate is measured from first product view
-- onward, not from total site traffic. See README Data Quality Findings: "Funnel Floor Bias."
--
-- VERIFIED RESULTS (run 2026-07-01):
--
-- Query 1 — Overall funnel (session-level):
--   sessions_with_view:     89,479,619
--   sessions_with_cart:     10,715,052   (11.97% of view sessions)
--   sessions_with_purchase:  5,449,933   (6.09% of view sessions)
--   cart_to_purchase_pct:   50.86%
--   NOTE: this figure is slightly inflated — see Query 3 note below.
--
-- Query 3 — Cart abandonment:
--   total_cart_sessions:    10,715,052
--   converted_cart_sessions: 4,919,641   (45.91% of cart sessions)
--   abandoned_cart_sessions:  5,795,411
--   abandonment_rate_pct:   54.09%
--
--   The difference between sessions_with_purchase (5,449,933) and
--   converted_cart_sessions (4,919,641) is 530,292 sessions that had a
--   purchase event with NO prior cart event in the same session (direct
--   purchases). Query 1's cart_to_purchase_pct divides all purchase sessions
--   by cart sessions, inflating the rate. The correct cart conversion rate
--   is 45.91% (from Query 3). Use Query 3 for abandonment reporting.
--
-- Query 2 — Funnel by top-level category (top 14 with >1,000 view sessions):
--   top_category    views       carts      purchases  overall_conv_pct
--   construction    23,052,672  3,462,460  1,898,778  8.24%  ← surprise leader
--   electronics     19,472,466  2,061,398  1,130,860  5.81%
--   appliances      15,715,297  1,615,685    786,186  5.00%
--   sport            5,712,881    593,960    265,666  4.65%
--   unknown         16,804,172  1,395,989    676,904  4.03%  ← NULL category_code rows
--   auto             1,457,937     93,210     48,078  3.30%
--   furniture        5,466,667    403,192    172,881  3.16%
--   computers        5,700,141    362,813    173,853  3.05%
--   apparel         12,854,885    929,354    388,777  3.02%
--   country_yard       345,259     26,255      9,532  2.76%
--   kids             3,185,391    190,142     82,423  2.59%
--   medicine           104,580      5,490      2,313  2.21%
--   accessories      1,798,835     83,206     32,599  1.81%
--   stationery          84,074      4,592      1,502  1.79%
--
--   Key insight: "construction" leads conversion at 8.24% — well above the
--   6.09% overall average. High-intent category (project-driven purchases).
--   Electronics + appliances dominate by volume but convert below average.
--
-- Query 4 — Funnel by brand (top 20 by purchase volume):
--   brand     views       purchases  overall_conv_pct  cart_to_purch_pct
--   samsung   16,383,360  1,279,265  7.81%             57.42%
--   apple     12,545,341    997,688  7.95%             57.00%  ← highest volume + best conversion
--   xiaomi     8,975,402    457,372  5.10%             47.52%
--   huawei     3,534,417    190,515  5.39%             55.96%
--   oppo       1,670,660     99,562  5.96%             58.10%
--   lucente    2,017,765     91,893  4.55%             63.96%  ← highest cart→purchase rate
--   lg         1,910,874     77,650  4.06%             48.86%
--   sony       1,915,499     65,243  3.41%             46.74%
--   (remaining 12 brands omitted for brevity — see query output)
--
--   Key insights:
--   - Apple (7.95%) and Samsung (7.81%) lead both volume AND conversion —
--     dual winners, typical of high-brand-loyalty consumer electronics.
--   - Lucente has the highest cart→purchase rate (63.96%) despite lower volume
--     — strong purchase intent once carted, likely a premium/niche brand.
--   - Top 5 brands are all mobile/electronics, confirming the category dominance.

-- ============================================================
-- Query 1: Overall funnel (session-level)
-- Unit: unique sessions that contain at least one event of each type.
-- "session" = user_session UUID; a single session can only count once per stage.
-- ============================================================
WITH funnel AS (
  SELECT
    COUNT(DISTINCT CASE WHEN event_type = 'view'     THEN user_session END) AS sessions_with_view,
    COUNT(DISTINCT CASE WHEN event_type = 'cart'     THEN user_session END) AS sessions_with_cart,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_session END) AS sessions_with_purchase
  FROM `instant-form-500912-n7.rees46.events`
)
SELECT
  sessions_with_view,
  sessions_with_cart,
  sessions_with_purchase,
  ROUND(sessions_with_cart     * 100.0 / sessions_with_view, 2) AS view_to_cart_pct,
  ROUND(sessions_with_purchase * 100.0 / sessions_with_cart, 2) AS cart_to_purchase_pct,
  ROUND(sessions_with_purchase * 100.0 / sessions_with_view, 2) AS overall_conversion_pct
FROM funnel;


-- ============================================================
-- Query 2: Funnel by top-level category
-- Top-level category = first segment of category_code before the dot.
-- NULLs grouped as 'unknown'.
-- Filtered to categories with >1,000 sessions to exclude noise.
-- ============================================================
WITH category_funnel AS (
  SELECT
    SPLIT(COALESCE(category_code, 'unknown'), '.')[OFFSET(0)] AS top_category,
    COUNT(DISTINCT CASE WHEN event_type = 'view'     THEN user_session END) AS views,
    COUNT(DISTINCT CASE WHEN event_type = 'cart'     THEN user_session END) AS carts,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_session END) AS purchases
  FROM `instant-form-500912-n7.rees46.events`
  GROUP BY top_category
)
SELECT
  top_category,
  views,
  carts,
  purchases,
  ROUND(carts     * 100.0 / NULLIF(views, 0), 2) AS view_to_cart_pct,
  ROUND(purchases * 100.0 / NULLIF(carts, 0), 2)  AS cart_to_purchase_pct,
  ROUND(purchases * 100.0 / NULLIF(views, 0), 2)  AS overall_conversion_pct
FROM category_funnel
WHERE views > 1000
ORDER BY overall_conversion_pct DESC
LIMIT 20;


-- ============================================================
-- Query 3: Cart abandonment rate
-- A session is "abandoned" if it has a cart event but NO purchase event.
-- A session is "converted" if it has both a cart event AND a purchase event.
-- Note: sessions with only views (no cart) are excluded from this metric —
--       abandonment only measures users who reached the cart stage.
-- ============================================================
WITH cart_sessions AS (
  SELECT DISTINCT user_session
  FROM `instant-form-500912-n7.rees46.events`
  WHERE event_type = 'cart'
),
purchase_sessions AS (
  SELECT DISTINCT user_session
  FROM `instant-form-500912-n7.rees46.events`
  WHERE event_type = 'purchase'
)
SELECT
  COUNT(DISTINCT cs.user_session)                                        AS total_cart_sessions,
  COUNT(DISTINCT ps.user_session)                                        AS converted_cart_sessions,
  COUNT(DISTINCT cs.user_session) - COUNT(DISTINCT ps.user_session)      AS abandoned_cart_sessions,
  ROUND(
    (COUNT(DISTINCT cs.user_session) - COUNT(DISTINCT ps.user_session))
    * 100.0 / COUNT(DISTINCT cs.user_session),
    2
  )                                                                       AS abandonment_rate_pct
FROM cart_sessions cs
LEFT JOIN purchase_sessions ps USING (user_session);


-- ============================================================
-- Query 4: Funnel by brand (top 20 by purchase volume)
-- Same session-level deduplication as Query 1.
-- Brand NULL rows excluded.
-- ============================================================
WITH brand_funnel AS (
  SELECT
    brand,
    COUNT(DISTINCT CASE WHEN event_type = 'view'     THEN user_session END) AS views,
    COUNT(DISTINCT CASE WHEN event_type = 'cart'     THEN user_session END) AS carts,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_session END) AS purchases
  FROM `instant-form-500912-n7.rees46.events`
  WHERE brand IS NOT NULL
  GROUP BY brand
)
SELECT
  brand,
  views,
  carts,
  purchases,
  ROUND(carts     * 100.0 / NULLIF(views, 0), 2) AS view_to_cart_pct,
  ROUND(purchases * 100.0 / NULLIF(carts, 0), 2)  AS cart_to_purchase_pct,
  ROUND(purchases * 100.0 / NULLIF(views, 0), 2)  AS overall_conversion_pct
FROM brand_funnel
WHERE views > 1000
ORDER BY purchases DESC
LIMIT 20;
