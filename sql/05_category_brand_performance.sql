-- Module 5: Category & Brand Performance
-- Business question: What drives revenue and where is demand concentrated?
-- Table: instant-form-500912-n7.rees46.events (411,709,736 events, Oct 2019 – Apr 2020)
-- SQL-only module — no Python notebook required.
--
-- CATEGORY CODE STRUCTURE:
--   Raw category_code is dot-delimited: "electronics.tablet", "appliances.kitchen.refrigerators"
--   SPLIT(...)[OFFSET(0)] extracts the top-level category segment.
--   NULLs (~15% of rows) are coalesced to 'unknown'.
--   A display-name CASE maps raw codes to human-readable labels in every query.
--
-- EXECUTION ORDER:
--   Query 1 — Category revenue + full funnel metrics (main deliverable, run first)
--   Query 2 — Overall brand revenue ranking across all categories (top 30)
--   Query 3 — Top 10 brands within the top-5 revenue categories
--   Query 4 — Monthly revenue trend by top-8 category (feeds Module 7 COVID context)
--
-- VERIFIED RESULTS (run 2026-07-02):
--
-- Query 1 — Category revenue + funnel:
--   category                  views       carts     purchases  total_revenue   avg_price  v→cart  cart→pur  v→pur
--   DIY / Home Improvement  77,482,657  6,301,358  2,442,248  1,008,523,959   412.95     8.13%   38.76%    3.15%
--   Electronics             69,201,207  3,454,692  1,341,139    511,171,792   381.15     4.99%   38.82%    1.94%
--   Appliances              63,417,883  2,746,239    925,763    237,020,688   256.03     4.33%   33.71%    1.46%
--   Unknown / No Category   62,105,978  2,297,725    768,060     99,842,875   129.99     3.70%   33.43%    1.24%
--   apparel                 41,137,209  1,490,365    455,370     62,552,043   137.37     3.62%   30.55%    1.11%
--   Computers & Peripherals 18,733,089    563,837    202,396     49,987,328   246.98     3.01%   35.90%    1.08%
--   Sports & Outdoor        16,145,807    989,574    316,243     41,518,787   131.29     6.13%   31.96%    1.96%
--   Furniture & Home        17,652,355    638,785    197,485     23,122,285   117.08     3.62%   30.92%    1.12%
--   Kids & Toys              9,128,630    303,934     93,757     10,656,740   113.66     3.33%   30.85%    1.03%
--   Automotive               4,645,771    145,094     54,205     10,086,682   186.08     3.12%   37.36%    1.17%
--   accessories              4,806,168    127,041     36,854      2,373,373    64.40     2.64%   29.01%    0.77%
--   Garden & Dacha             841,274     40,206     10,849        389,100    35.87     4.78%   26.98%    1.29%
--   Stationery & Office        172,368      6,960      1,872        124,160    66.32     4.04%   26.90%    1.09%
--   Health & Medicine          276,453      8,253      2,583         77,416    29.97     2.99%   31.30%    0.93%
--
-- Query 2 — Top 30 brands by revenue:
--   brand        purchases   total_revenue    avg_price   categories  v→pur
--   apple       1,246,326   929,321,587      745.65      11          4.00%
--   samsung     1,567,074   425,423,961      271.48      12          3.49%
--   xiaomi        542,848    91,406,924      168.38      13          2.13%
--   huawei        227,722    42,203,598      185.33      10          2.43%
--   lg             91,108    38,260,344      419.94       9          1.74%
--   acer           61,939    31,996,239      516.58       8          1.47%
--   sony           75,995    28,528,875      375.40      12          1.65%
--   lucente       108,910    28,410,590      260.86      10          1.89%
--   oppo          119,433    26,428,298      221.28       3          2.79%
--   lenovo         57,028    22,197,927      389.25       9          1.32%
--   thermomix       3,257     5,481,883    1,683.11       1          4.01%
--   (top 10 + thermomix highlighted — see full results in csv export)
--
-- Query 3 — Top brands per top-5 categories:
--   DIY/Home Improvement rank 1: apple   (618M, avg 867.82)  ← SEE ANOMALY NOTE BELOW
--   DIY/Home Improvement rank 2: samsung (250M, avg 255.24)
--   DIY/Home Improvement rank 3: xiaomi  (60M,  avg 200.99)
--   Electronics rank 1: apple   (273M, avg 725.16)
--   Electronics rank 2: samsung (99M,  avg 274.33)
--   Appliances rank 1: samsung  (68M,  avg 408.60)
--   Appliances rank 2: lg       (32M,  avg 447.39)
--   apparel rank 1: sony        (15M,  avg 371.36)  ← anomaly: Sony electronics in apparel
--   Unknown/No Category rank 4: cordiant (2.5M, avg 45.21) ← Cordiant = tire brand
--
-- Query 4 — Monthly revenue trend (top 8 categories):
--   2019-10: Electronics 176.5M, Unknown 22.9M, Appliances 13.6M, Computers 11.4M
--            DIY / Home Improvement: 932,995 (< 1M)
--   2019-11: Electronics 205.3M, Unknown 29.9M, Appliances 18.6M, Computers 14.0M
--            DIY / Home Improvement: 1,080,391 (< 1.1M)
--   2019-12: DIY / Home Improvement SURGES to 217.9M (#1!)
--            Electronics collapses to 25.4M (was 176–205M prior months)
--   2020-01: DIY 176.1M, Appliances 34.5M, Electronics 17.9M
--   2020-02: DIY 269.7M (peak), Appliances 37.3M, Electronics 28.0M
--   2020-03: DIY 206.2M, Appliances 39.7M, Electronics 30.4M
--   2020-04: DIY 136.7M, Appliances 42.8M, Electronics 27.8M
--
-- CRITICAL ANOMALY — CATEGORY TAXONOMY ISSUE:
--   The raw category_code = 'construction' houses Apple, Samsung, and Xiaomi as its
--   top-3 brands (iPhone avg ~$868 in "DIY"). The construction category was near-zero
--   in Oct–Nov 2019 (< $1.1M/month), then exploded to $217M in Dec 2019 and stayed
--   dominant for the rest of the dataset. This is not a genuine DIY/construction surge —
--   it reflects a platform taxonomy event: smartphones and consumer electronics that were
--   previously untagged or tagged as 'electronics' began appearing under 'construction'
--   starting December 2019. The display name "DIY / Home Improvement" is misleading.
--   Interpretation rule: treat 'construction' as a catch-all / misclassified electronics
--   bucket. Module 6 (Anomaly Detection) should flag this timestamp-bound shift.
--
-- Key insights:
-- 1. Total platform revenue: ~2.06B across all categories.
--    DIY/Home Improvement (construction) accounts for ~49% — but this is the taxonomy
--    artifact described above. Genuine DIY share in Oct-Nov was negligible.
-- 2. True #1 revenue category pre-December: Electronics, consistent at 176M–205M/month.
--    After Dec 2019 the category mix inverts due to the construction taxonomy event.
-- 3. Electronics and Automotive have the highest cart-to-purchase rates (~38-39%).
--    Once users add to cart in these categories, they almost always buy.
--    Sports & Outdoor is a strong view-to-cart converter (6.13%) despite mid-tier revenue.
-- 4. Apple is the highest-revenue brand at 929M — driven by premium avg price ($745.65)
--    despite fewer purchases than Samsung (1.25M vs 1.57M). Samsung wins on volume,
--    Apple wins on value.
-- 5. Thermomix: only 3,257 purchases but avg price 1,683 and 4.01% view-to-purchase rate.
--    The most premium brand in the dataset with high purchase intent — a niche but loyal buyer.
-- 6. Garden & Dacha: smallest revenue category (389K), lowest avg price (35.87), and
--    very low total volume — niche seasonal category, essentially irrelevant to dashboard.
-- 7. apparel + Sony at rank 1 (15M) and cordiant tires in Unknown/No Category confirm
--    that category_code is unreliable across the board. Many high-value products have
--    incorrect or missing taxonomy. Use category metrics as directional, not definitive.


-- ============================================================
-- Query 1: Category performance — revenue + funnel metrics
-- Unit: one row per top-level category.
-- Funnel: view → cart → purchase conversion rates.
-- Filter: categories with >10,000 views (removes long-tail noise).
-- ============================================================
WITH category_raw AS (
  SELECT
    SPLIT(COALESCE(category_code, 'unknown'), '.')[OFFSET(0)]   AS raw_category,
    COUNT(CASE WHEN event_type = 'view'     THEN 1 END)          AS total_views,
    COUNT(CASE WHEN event_type = 'cart'     THEN 1 END)          AS total_carts,
    COUNT(CASE WHEN event_type = 'purchase' THEN 1 END)          AS total_purchases,
    ROUND(
      SUM(CASE WHEN event_type = 'purchase' AND price > 0
               THEN price ELSE 0 END), 2)                        AS total_revenue,
    ROUND(
      AVG(CASE WHEN event_type = 'purchase' AND price > 0
               THEN price END), 2)                               AS avg_purchase_price
  FROM `instant-form-500912-n7.rees46.events`
  GROUP BY raw_category
  HAVING total_views > 10000
)
SELECT
  CASE raw_category
    WHEN 'electronics'  THEN 'Electronics'
    WHEN 'appliances'   THEN 'Appliances'
    WHEN 'computers'    THEN 'Computers & Peripherals'
    WHEN 'construction' THEN 'DIY / Home Improvement'
    WHEN 'country_yard' THEN 'Garden & Dacha'
    WHEN 'sport'        THEN 'Sports & Outdoor'
    WHEN 'auto'         THEN 'Automotive'
    WHEN 'furniture'    THEN 'Furniture & Home'
    WHEN 'kids'         THEN 'Kids & Toys'
    WHEN 'medicine'     THEN 'Health & Medicine'
    WHEN 'stationery'   THEN 'Stationery & Office'
    WHEN 'unknown'      THEN 'Unknown / No Category'
    ELSE raw_category
  END                                                             AS category,
  total_views,
  total_carts,
  total_purchases,
  total_revenue,
  avg_purchase_price,
  ROUND(total_carts     * 100.0 / NULLIF(total_views, 0), 2)    AS view_to_cart_pct,
  ROUND(total_purchases * 100.0 / NULLIF(total_carts, 0), 2)    AS cart_to_purchase_pct,
  ROUND(total_purchases * 100.0 / NULLIF(total_views, 0), 2)    AS view_to_purchase_pct
FROM category_raw
ORDER BY total_revenue DESC;


-- ============================================================
-- Query 2: Brand revenue ranking — all categories combined
-- Identifies the platform's highest-grossing brands overall.
-- NULL brands are excluded (many view events have no brand set).
-- Filter: brands with >100 purchases to suppress long-tail noise.
-- ============================================================
SELECT
  brand,
  COUNT(CASE WHEN event_type = 'purchase' THEN 1 END)             AS total_purchases,
  ROUND(
    SUM(CASE WHEN event_type = 'purchase' AND price > 0
             THEN price ELSE 0 END), 2)                            AS total_revenue,
  ROUND(
    AVG(CASE WHEN event_type = 'purchase' AND price > 0
             THEN price END), 2)                                   AS avg_purchase_price,
  COUNT(DISTINCT
    SPLIT(COALESCE(category_code, 'unknown'), '.')[OFFSET(0)])     AS category_count,
  ROUND(
    COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) * 100.0 /
    NULLIF(COUNT(CASE WHEN event_type = 'view' THEN 1 END), 0),
    2)                                                             AS view_to_purchase_pct
FROM `instant-form-500912-n7.rees46.events`
WHERE brand IS NOT NULL
GROUP BY brand
HAVING total_purchases > 100
ORDER BY total_revenue DESC
LIMIT 30;


-- ============================================================
-- Query 3: Top 10 brands within the top-5 revenue categories
-- Answers: which brands dominate the highest-revenue categories?
-- Pattern: identify top-5 categories → rank brands within each.
-- ============================================================
WITH top_categories AS (
  SELECT
    SPLIT(COALESCE(category_code, 'unknown'), '.')[OFFSET(0)] AS raw_category,
    SUM(price)                                                 AS cat_revenue
  FROM `instant-form-500912-n7.rees46.events`
  WHERE event_type = 'purchase' AND price > 0
  GROUP BY raw_category
  ORDER BY cat_revenue DESC
  LIMIT 5
),
brand_category_agg AS (
  SELECT
    SPLIT(COALESCE(e.category_code, 'unknown'), '.')[OFFSET(0)] AS raw_category,
    e.brand,
    COUNT(*)                   AS total_purchases,
    ROUND(SUM(e.price), 2)     AS total_revenue,
    ROUND(AVG(e.price), 2)     AS avg_purchase_price
  FROM `instant-form-500912-n7.rees46.events` e
  INNER JOIN top_categories tc
    ON SPLIT(COALESCE(e.category_code, 'unknown'), '.')[OFFSET(0)] = tc.raw_category
  WHERE e.event_type = 'purchase'
    AND e.price > 0
    AND e.brand IS NOT NULL
  GROUP BY raw_category, e.brand
),
ranked AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY raw_category
      ORDER BY total_revenue DESC
    ) AS brand_rank
  FROM brand_category_agg
)
SELECT
  CASE raw_category
    WHEN 'electronics'  THEN 'Electronics'
    WHEN 'appliances'   THEN 'Appliances'
    WHEN 'computers'    THEN 'Computers & Peripherals'
    WHEN 'construction' THEN 'DIY / Home Improvement'
    WHEN 'country_yard' THEN 'Garden & Dacha'
    WHEN 'sport'        THEN 'Sports & Outdoor'
    WHEN 'auto'         THEN 'Automotive'
    WHEN 'furniture'    THEN 'Furniture & Home'
    WHEN 'kids'         THEN 'Kids & Toys'
    WHEN 'medicine'     THEN 'Health & Medicine'
    WHEN 'stationery'   THEN 'Stationery & Office'
    WHEN 'unknown'      THEN 'Unknown / No Category'
    ELSE raw_category
  END                  AS category,
  brand,
  brand_rank,
  total_purchases,
  total_revenue,
  avg_purchase_price
FROM ranked
WHERE brand_rank <= 10
ORDER BY total_revenue DESC, brand_rank;


-- ============================================================
-- Query 4: Monthly revenue trend by top-8 category
-- One row per (category, month). Covers Oct 2019 – Apr 2020.
-- Used to visualise category-level growth and the COVID demand
-- shift in Module 7 (COVID Quasi-Experiment).
-- ============================================================
WITH monthly_raw AS (
  SELECT
    SPLIT(COALESCE(category_code, 'unknown'), '.')[OFFSET(0)] AS raw_category,
    FORMAT_DATE('%Y-%m', DATE(event_time))                     AS month,
    ROUND(SUM(price), 2)                                       AS monthly_revenue,
    COUNT(*)                                                   AS purchase_count
  FROM `instant-form-500912-n7.rees46.events`
  WHERE event_type = 'purchase' AND price > 0
  GROUP BY raw_category, month
),
top_cats AS (
  SELECT raw_category
  FROM monthly_raw
  GROUP BY raw_category
  ORDER BY SUM(monthly_revenue) DESC
  LIMIT 8
)
SELECT
  CASE mr.raw_category
    WHEN 'electronics'  THEN 'Electronics'
    WHEN 'appliances'   THEN 'Appliances'
    WHEN 'computers'    THEN 'Computers & Peripherals'
    WHEN 'construction' THEN 'DIY / Home Improvement'
    WHEN 'country_yard' THEN 'Garden & Dacha'
    WHEN 'sport'        THEN 'Sports & Outdoor'
    WHEN 'auto'         THEN 'Automotive'
    WHEN 'furniture'    THEN 'Furniture & Home'
    WHEN 'kids'         THEN 'Kids & Toys'
    WHEN 'medicine'     THEN 'Health & Medicine'
    WHEN 'stationery'   THEN 'Stationery & Office'
    WHEN 'unknown'      THEN 'Unknown / No Category'
    ELSE mr.raw_category
  END              AS category,
  mr.month,
  mr.monthly_revenue,
  mr.purchase_count
FROM monthly_raw mr
INNER JOIN top_cats tc USING (raw_category)
ORDER BY mr.month, mr.monthly_revenue DESC;
