# Workflow: Analytics Plan

## Objective

Build all analytical deliverables from the REES46 dataset in BigQuery, in the correct sequence. Each module produces SQL queries (saved in `sql/`), Python analysis (saved in `notebooks/`), and feeds the final dashboard and Excel report.

## Prerequisites

- BigQuery table loaded and verified (see `workflows/01_bigquery_setup.md`)
- Python environment with dependencies from `requirements.txt`

---

## BigQuery Studio Features — Decisions

BigQuery Studio exposes several features beyond the standard query editor. Decisions on what to use:

| Feature | Decision | Reason |
| ------- | -------- | ------ |
| **Data Canvas** | Reference artifact only | Used for quick EDA; visualization nodes have a partial-snapshot limitation. Screenshot saved to `dashboards/`. Not a formal module. |
| **Notebooks (BQ Studio)** | Skip — use SQL editor directly | Modules 1, 2, 5 are SQL-only. BQ Studio's query editor already handles this; a notebook wrapping `%%bigquery` cells adds friction with no benefit. |
| **Notebooks (local Jupyter)** | Use for modules 3, 4, 7 | Python does real work here: seaborn cohort heatmap, RFM box plots, z-test charts. These can't be produced in the SQL editor. |
| **Conversations / Agents** | Skip | AI-assisted querying hides analytical thinking — wrong signal for portfolio. |
| **Data preparations** | Skip | Project uses ELT pattern (clean in SQL). Dataprep would duplicate this transparently. |
| **Pipelines** | Skip | Adds significant scope. Flag for Project 3 instead. |
| **Connections** | Skip | Not needed — single source (rees46 table in same project). |

---

## Build Order

Build in this sequence. Each module builds on the previous.

```text
Module 1: Funnel Analysis        ← start here, validates the data works end-to-end
Module 2: Session Analytics      ← depends on session-level understanding from M1
Module 3: RFM Segmentation       ← depends on purchase-only subset from M1
Module 4: Cohort Retention       ← depends on RFM user table from M3
Module 5: Category & Brand Perf  ← independent, can run anytime after M1
Module 6: Anomaly Detection      ← depends on price/volume baseline from M5
Module 7: COVID Quasi-Experiment ← depends on all prior modules for context
```

---

## Data Canvas EDA (Reference Artifact — Not a Module)

BigQuery Studio's Data Canvas was used for a quick visual exploration before Module 1. Two charts were produced:

- **Event type split** — views (~375M) vs carts (~25M) vs purchases (~10M). Confirms the extreme funnel drop-off that drives the central project question.
- **Top categories by volume** — electronics and appliances dominate; "unknown" reflects NULL `category_code` rows handled via `COALESCE`.

**Canvas limitation encountered:** Visualization nodes snapshot partial query results into their Vega-Lite JSON spec rather than dynamically reading from the parent query node. Multi-series line charts are not reliably supported. Data Canvas is suited to single-metric, single-dimension bar charts only.

**Artifact:** Screenshot saved as `dashboards/00_data_canvas_eda.png`. Not featured in the README — it is a process artifact, not an analytical deliverable. The monthly trend and all analytical charts belong in notebooks.

---

## Module 1: Funnel Analysis

**Business question:** What is the conversion rate from view → cart → purchase, and where does it break down?

**SQL pattern — overall funnel:**
```sql
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
  ROUND(sessions_with_cart * 100.0 / sessions_with_view, 2) AS view_to_cart_pct,
  ROUND(sessions_with_purchase * 100.0 / sessions_with_cart, 2) AS cart_to_purchase_pct,
  ROUND(sessions_with_purchase * 100.0 / sessions_with_view, 2) AS overall_conversion_pct
FROM funnel;
```

**SQL pattern — funnel by top-level category:**
```sql
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
  ROUND(purchases * 100.0 / NULLIF(views, 0), 2) AS conversion_pct
FROM category_funnel
WHERE views > 1000
ORDER BY conversion_pct DESC
LIMIT 20;
```

**Cart abandonment:**
```sql
SELECT
  COUNT(DISTINCT cart_sessions.user_session) AS abandoned_carts,
  COUNT(DISTINCT purchase_sessions.user_session) AS converted_carts,
  ROUND(
    COUNT(DISTINCT cart_sessions.user_session) * 100.0 /
    (COUNT(DISTINCT cart_sessions.user_session) + COUNT(DISTINCT purchase_sessions.user_session)),
    2
  ) AS abandonment_rate_pct
FROM
  (SELECT DISTINCT user_session FROM `instant-form-500912-n7.rees46.events`
   WHERE event_type = 'cart') AS cart_sessions
LEFT JOIN
  (SELECT DISTINCT user_session FROM `instant-form-500912-n7.rees46.events`
   WHERE event_type = 'purchase') AS purchase_sessions
USING (user_session);
```

**Output:** Save SQL to `sql/01_funnel_analysis.sql`. Record key metrics in notebook `notebooks/01_funnel_analysis.ipynb`.

---

## Module 2: Session Analytics

**Business question:** How do users browse before they buy?

**SQL pattern — events per session:**
```sql
SELECT
  user_session,
  COUNT(*) AS total_events,
  COUNT(CASE WHEN event_type = 'view'     THEN 1 END) AS views,
  COUNT(CASE WHEN event_type = 'cart'     THEN 1 END) AS carts,
  COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) AS purchases,
  MIN(event_time) AS session_start,
  MAX(event_time) AS session_end,
  TIMESTAMP_DIFF(MAX(event_time), MIN(event_time), SECOND) AS session_duration_seconds
FROM `instant-form-500912-n7.rees46.events`
GROUP BY user_session
```

**SQL pattern — session depth before purchase:**
```sql
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
  APPROX_QUANTILES(event_rank, 100)[OFFSET(50)] AS median_events_before_purchase,
  AVG(event_rank) AS avg_events_before_purchase,
  MAX(event_rank) AS max_events_before_purchase
FROM session_events
JOIN purchase_sessions USING (user_session)
WHERE event_type = 'purchase';
```

**Output:** Save SQL to `sql/02_session_analytics.sql`. Visualize event count distribution in Python.

---

## Module 3: RFM Segmentation

**Business question:** Who are the best customers?

**SQL pattern — compute RFM scores:**
```sql
-- Reference date: day after last event in dataset
-- Max date in data is approximately 2020-04-30

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
    DATE_DIFF(DATE '2020-05-01', MAX(DATE(event_time)), DAY) AS recency_days,
    COUNT(*) AS frequency,
    SUM(price) AS monetary
  FROM purchase_events
  GROUP BY user_id
),
rfm_scored AS (
  SELECT
    user_id,
    recency_days,
    frequency,
    monetary,
    NTILE(5) OVER (ORDER BY recency_days ASC)  AS r_score,  -- lower recency = better
    NTILE(5) OVER (ORDER BY frequency DESC)    AS f_score,
    NTILE(5) OVER (ORDER BY monetary DESC)     AS m_score
  FROM rfm_raw
)
SELECT
  user_id,
  recency_days,
  frequency,
  ROUND(monetary, 2) AS monetary,
  r_score,
  f_score,
  m_score,
  r_score + f_score + m_score AS rfm_total,
  CASE
    WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champion'
    WHEN r_score >= 3 AND f_score >= 3                  THEN 'Loyal'
    WHEN r_score >= 4 AND f_score <= 2                  THEN 'Recent but Infrequent'
    WHEN r_score <= 2 AND f_score >= 3                  THEN 'At Risk'
    WHEN r_score = 1 AND f_score = 1                    THEN 'Lost'
    ELSE 'Others'
  END AS segment
FROM rfm_scored;
```

Save this result as a BigQuery table: `rees46.rfm_segments` — **required by Module 4**.

**Output:** Save SQL to `sql/03_rfm_segmentation.sql`. Python notebook: segment distribution pie chart, monetary value by segment box plot.

---

## Module 4: Cohort Retention

**Business question:** Do customers come back month after month?

**Prerequisite:** `rees46.rfm_segments` table must exist (created in Module 3).

**SQL pattern — monthly cohort retention:**
```sql
WITH first_purchase AS (
  SELECT
    user_id,
    DATE_TRUNC(MIN(DATE(event_time)), MONTH) AS cohort_month
  FROM `instant-form-500912-n7.rees46.events`
  WHERE event_type = 'purchase'
  GROUP BY user_id
),
user_purchases AS (
  SELECT
    e.user_id,
    DATE_TRUNC(DATE(e.event_time), MONTH) AS purchase_month
  FROM `instant-form-500912-n7.rees46.events` e
  WHERE e.event_type = 'purchase'
),
cohort_data AS (
  SELECT
    fp.cohort_month,
    up.purchase_month,
    DATE_DIFF(up.purchase_month, fp.cohort_month, MONTH) AS months_since_first,
    COUNT(DISTINCT up.user_id) AS active_users
  FROM first_purchase fp
  JOIN user_purchases up USING (user_id)
  GROUP BY fp.cohort_month, up.purchase_month, months_since_first
),
cohort_size AS (
  SELECT cohort_month, COUNT(DISTINCT user_id) AS cohort_users
  FROM first_purchase
  GROUP BY cohort_month
)
SELECT
  cd.cohort_month,
  cs.cohort_users,
  cd.months_since_first,
  cd.active_users,
  ROUND(cd.active_users * 100.0 / cs.cohort_users, 2) AS retention_rate
FROM cohort_data cd
JOIN cohort_size cs USING (cohort_month)
ORDER BY cd.cohort_month, cd.months_since_first;
```

**Python:** Use pandas to pivot into a cohort matrix. Seaborn heatmap for visualization.

**Output:** Save SQL to `sql/04_cohort_retention.sql`. Python notebook: cohort heatmap.

---

## Module 5: Category & Brand Performance

**Business question:** What drives revenue and where is demand concentrated?

**SQL pattern — category performance:**
```sql
SELECT
  SPLIT(COALESCE(category_code, 'unknown'), '.')[OFFSET(0)] AS top_category,
  COUNT(CASE WHEN event_type = 'view'     THEN 1 END) AS total_views,
  COUNT(CASE WHEN event_type = 'cart'     THEN 1 END) AS total_carts,
  COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) AS total_purchases,
  ROUND(SUM(CASE WHEN event_type = 'purchase' THEN price ELSE 0 END), 2) AS total_revenue,
  ROUND(AVG(CASE WHEN event_type = 'purchase' THEN price END), 2) AS avg_purchase_price,
  ROUND(COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) * 100.0 /
        NULLIF(COUNT(CASE WHEN event_type = 'view' THEN 1 END), 0), 2) AS view_to_purchase_pct
FROM `instant-form-500912-n7.rees46.events`
WHERE price > 0 OR event_type = 'view'
GROUP BY top_category
HAVING total_views > 10000
ORDER BY total_revenue DESC;
```

**Output:** Save SQL to `sql/05_category_brand_performance.sql`.

---

## Module 6: Anomaly Detection

**Business question:** What purchase patterns look unusual?

**SQL pattern — price outliers by category (IQR method):**
```sql
WITH category_stats AS (
  SELECT
    SPLIT(COALESCE(category_code, 'unknown'), '.')[OFFSET(0)] AS top_category,
    APPROX_QUANTILES(price, 4)[OFFSET(1)] AS q1,
    APPROX_QUANTILES(price, 4)[OFFSET(3)] AS q3
  FROM `instant-form-500912-n7.rees46.events`
  WHERE event_type = 'purchase' AND price > 0
  GROUP BY top_category
)
SELECT
  e.user_id,
  e.user_session,
  e.event_time,
  SPLIT(COALESCE(e.category_code, 'unknown'), '.')[OFFSET(0)] AS top_category,
  e.brand,
  e.price,
  cs.q1,
  cs.q3,
  (cs.q3 - cs.q1) * 1.5 AS iqr_fence,
  cs.q3 + (cs.q3 - cs.q1) * 1.5 AS upper_fence
FROM `instant-form-500912-n7.rees46.events` e
JOIN category_stats cs
  ON SPLIT(COALESCE(e.category_code, 'unknown'), '.')[OFFSET(0)] = cs.top_category
WHERE e.event_type = 'purchase'
  AND e.price > cs.q3 + (cs.q3 - cs.q1) * 1.5
ORDER BY e.price DESC
LIMIT 1000;
```

**SQL pattern — high-frequency session anomalies (bot signal):**
```sql
SELECT
  user_id,
  user_session,
  COUNT(*) AS events_in_session,
  COUNT(DISTINCT product_id) AS distinct_products,
  SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchases
FROM `instant-form-500912-n7.rees46.events`
GROUP BY user_id, user_session
HAVING events_in_session > 500  -- threshold: adjust based on distribution
ORDER BY events_in_session DESC;
```

**Output:** Save SQL to `sql/06_anomaly_detection.sql`. Document findings as insights, not just flagged rows.

---

## Module 7: COVID Quasi-Experiment

**Business question:** Did the COVID-19 onset (March 2020) change purchasing behavior?

**Treatment definition:**
- Control (pre-COVID): October 2019 – February 2020 (5 months)
- Treatment (COVID onset): March 2020 – April 2020 (2 months)

**SQL pattern — conversion rate by period:**
```sql
WITH period_sessions AS (
  SELECT
    user_session,
    CASE
      WHEN DATE(event_time) < '2020-03-01' THEN 'pre_covid'
      ELSE 'covid_onset'
    END AS period,
    MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS converted
  FROM `instant-form-500912-n7.rees46.events`
  GROUP BY user_session, period
)
SELECT
  period,
  COUNT(*) AS total_sessions,
  SUM(converted) AS converted_sessions,
  ROUND(SUM(converted) * 100.0 / COUNT(*), 4) AS conversion_rate_pct
FROM period_sessions
GROUP BY period;
```

**Python statistical test:**
```python
from scipy import stats

# Fill in from BigQuery query results
pre_covid_converted = ...
pre_covid_total = ...
covid_converted = ...
covid_total = ...

# Two-proportion z-test
count = [pre_covid_converted, covid_converted]
nobs = [pre_covid_total, covid_total]
z_stat, p_value = stats.proportions_ztest(count, nobs)

print(f"Z-stat: {z_stat:.4f}")
print(f"P-value: {p_value:.6f}")
print(f"Significant at α=0.05: {p_value < 0.05}")
```

**Also measure:**
- AOV (average order value) pre vs. during COVID
- Category mix shift (which categories grew/fell)
- Session frequency change (are users browsing more or less?)

**Output:** Save SQL to `sql/07_covid_experiment.sql`. Python notebook with statistical test: `notebooks/07_covid_experiment.ipynb`.

---

## Output Artifacts

By the end of all modules, the project should have:

```
dashboards/
  00_data_canvas_eda.png         (screenshot of BigQuery Studio Data Canvas)
  ecommerce_analytics.pbix       (Power BI Report — 5 pages)
  ecommerce_analytics.xlsx       (Excel equivalent — same KPIs, static)

sql/
  01_funnel_analysis.sql
  02_session_analytics.sql
  03_rfm_segmentation.sql
  04_cohort_retention.sql
  05_category_brand_performance.sql
  06_anomaly_detection.sql
  07_covid_experiment.sql

notebooks/
  03_rfm_segmentation.ipynb      (local Jupyter — segment charts, box plots)
  04_cohort_retention.ipynb      (local Jupyter — cohort heatmap)
  07_covid_experiment.ipynb      (local Jupyter — z-test + before/after charts)
```

**Notebook routing rationale:** Modules 1, 2, 5 are SQL-only — run queries directly in BQ Studio's SQL editor. No notebook needed; a notebook wrapping `%%bigquery` cells adds friction with no benefit over the query editor. Local Jupyter notebooks only for modules 3, 4, 7 where Python does real work: seaborn cohort heatmap, RFM box plots, z-test charts.

---

## Dashboard Plan

### Power BI Report (`.pbix` — built in Power BI Desktop)

Connect to BigQuery using Import mode (data embedded in the file — works offline and survives the 60-day sandbox table expiry).

**5 pages:**

1. **Overview** — total events, purchase count, total revenue, conversion rate KPIs
2. **Funnel** — funnel chart (view → cart → purchase), abandonment rate, funnel by category
3. **Customer Segments** — RFM tier distribution, revenue by segment, cohort retention heatmap
4. **Category & Brand** — revenue ranking, view-to-purchase ratio, brand performance
5. **COVID Impact** — before/after conversion rate, AOV trend, category mix shift

### Power BI Service Dashboard (live alerts)

**Status: not built, deliberately.** Data Alerts require every recipient in the alert loop to hold a Power BI license inside the organization's own Fabric/Power BI tenancy. This project has no real tenancy and no real stakeholders to notify, so there's no one for the alerting layer to actually serve — see the README's "Real-world note on the Power BI Service Dashboard" for the full reasoning. Revisit this section once there's an actual deployment with licensed recipients and a genuine KPI-monitoring need.

After publishing the Report to Power BI Service, pin selected KPI cards to a **Dashboard** (separate from the Report — this is a canvas of tiles in the browser). Set Data Alerts on each tile so Power BI sends email notifications when values cross thresholds.

**7 alert KPIs to pin and configure:**

| KPI | Alert Condition | Stakeholder |
|-----|-----------------|-------------|
| Overall conversion rate | Falls below floor threshold | Product / CRO team |
| Cart abandonment rate | Rises above upper bound | UX / checkout team |
| Daily revenue | Deviates >2σ from rolling average | Revenue ops / leadership |
| Top-category conversion | Drops >20% week-over-week | Category management |
| Price outlier count | Exceeds historical baseline | Data quality / pricing |
| Bot session count | Sessions >500 events exceed baseline | Security / fraud team |
| Month-1 cohort retention | Latest cohort falls below historical P25 | Growth / retention |

### Excel Workbook (`ecommerce_analytics.xlsx`)

One sheet per module — same KPIs and key findings as the Power BI report, presented as static tables and charts. Generated programmatically via `tools/generate_excel_report.py` after all BigQuery result sets are exported. For stakeholders who do not have Power BI.
