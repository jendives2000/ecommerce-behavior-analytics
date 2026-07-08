# E-Commerce Behavior Analytics

> **411 million real behavioral events.**   
**One question: what separates a browser from a buyer?**  
> Most visitors view products and leave. Only ~6% actually purchase. This project identifies the behavioral signals that predict who converts — and what drives the gap — through funnel analysis, cohort retention, RFM segmentation, anomaly detection, and a COVID-onset quasi-experiment on real e-commerce data in Google BigQuery.

![BigQuery](https://img.shields.io/badge/BigQuery-Sandbox-4285F4?logo=googlecloud&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.11-blue?logo=python&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-CTEs%20%7C%20Window%20Functions-336791?logo=postgresql&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-F2C811?logo=powerbi&logoColor=black)

---

## Why This Project Exists

This is the second portfolio project in a two-project strategy:

| Project | Dataset | Domain | What it covers |
|---------|---------|--------|----------------|
| [Project 1 — TechFlow](../project1_saas_analytics/) | IBM Telco (7,043 records) | SaaS subscription | Churn, LTV, A/B test, Excel automation |
| **Project 2 — This project** | REES46 (411M events) | E-commerce behavior | Funnel, retention cohorts, RFM, anomaly detection |

Project 1 speaks to fintech/B2B SaaS roles. This project speaks to product analytics, gaming, e-commerce, and modern data stack roles — specifically the gap companies like Moon Active, Ashley Digital, and Nespresso represent in the Israeli job market.

The key portfolio signal: **event-level behavioral data in BigQuery**. GA4, Amplitude, and Mixpanel all produce the same structure (event_time, event_type, user_id, session_id). Knowing how to query it is the transferable skill.

---

## Dataset

**Source:** [eCommerce Behavior Data from Multi Category Store](https://www.kaggle.com/datasets/mkechinov/ecommerce-behavior-data-from-multi-category-store) — Kaggle / REES46 Open CDP

**Nature:** Real behavioral clickstream telemetry from a large live e-commerce platform. REES46 is a B2B SaaS Customer Data Platform — it does not operate a store. This data comes from an anonymous retail client that integrated REES46's tracking script. The client's identity is not publicly disclosed; domain research identifies the market as Kazakhstan / CIS based on brand inventory (Artel, Cordiant, Redmond, Vitek, Polaris, ARG).

**Category note:** Category codes are machine-translated from Russian retail schemas. `construction` = DIY & Home Improvement; `country_yard` = Garden & Dacha (outdoor/seasonal). This context is required to correctly interpret conversion rates by category.

**Scale:** 411 million events across 7 months (October 2019 – April 2020)

**Schema (flat, one row = one event):**

| Field | Type | Description |
|-------|------|-------------|
| `event_time` | TIMESTAMP | UTC timestamp of event |
| `event_type` | STRING | `view` / `cart` / `purchase` |
| `product_id` | INTEGER | Product identifier |
| `category_id` | INTEGER | Category identifier |
| `category_code` | STRING | Dot-separated category path (e.g. `electronics.smartphone`) |
| `brand` | STRING | Brand name |
| `price` | FLOAT | Product price at time of event |
| `user_id` | INTEGER | Persistent user identifier |
| `user_session` | STRING | Session UUID (resets per browsing session) |

**Event scope note:** This schema tracks only product-level interactions (`view` / `cart` / `purchase`) — there is no event for raw site visits, searches, or homepage browsing that never touches a specific product. Every conversion rate in this project is measured from first product view onward, not from total site traffic (see Data Quality Findings below).

**Time span significance:** Oct 2019 – Feb 2020 = pre-COVID baseline. Mar–Apr 2020 = COVID-onset period. Kazakhstan's first confirmed case was March 13, 2020; national lockdown began March 16. The dataset captures the behavioral shock from the exact week the country shut down — a unusually clean natural experiment.

**Files on Kaggle:** One CSV per month (Oct 2019, Nov 2019, Dec 2019, Jan 2020, Feb 2020, Mar 2020, Apr 2020). Each file ~5–6 GB uncompressed.

---

## Platform

**Google BigQuery Sandbox** — free tier, no credit card required.

- 10 GB free active storage
- 1 TB free query processing per month
- Public datasets don't count against quota
- Sandbox tables expire after 60 days (re-load from local CSVs if needed)

See `workflows/01_bigquery_setup.md` for setup and loading instructions.

---

## Analytics Deliverables

### 1. Funnel Analysis
**Question:** What is the conversion rate from view → cart → purchase, and where does it break down?
- Overall funnel conversion (view → cart → purchase)
- Funnel by category (which categories convert best/worst)
- Funnel by brand
- Cart abandonment rate: added to cart but never purchased

### 2. Session Analytics
**Question:** How do users browse before they buy?
- Events per session distribution
- Session-to-purchase conversion
- Time between first view and purchase within session

### 3. RFM Segmentation
**Question:** Who are the best customers?
- Recency: days since last purchase per user
- Frequency: number of purchase events per user
- Monetary: total spend per user (sum of price where event_type = 'purchase')
- Customer tier classification: Champions / Loyal / At-Risk / Lost

### 4. Cohort Retention
**Question:** Do customers come back?
- Monthly acquisition cohorts (first purchase month)
- 1-month, 2-month, 3-month, 6-month retention rates
- Retention heatmap by cohort

### 5. Category & Brand Performance
**Question:** What drives revenue?
- Revenue by top-level category (split `category_code` on first dot)
- View-to-purchase ratio by category (demand signal vs conversion)
- Top brands by purchase volume and by conversion rate

### 6. Anomaly Detection
**Question:** What purchase patterns look suspicious or unusual?
- Price outliers by category (IQR method)
- Sessions with unusually high event volume
- User-level purchase frequency anomalies (potential bot/fraud signal)

### 7. COVID Quasi-Experiment
**Question:** Did the COVID-19 onset (March 2020) measurably change purchasing behavior?
- Pre-COVID baseline: Oct 2019 – Feb 2020 (5 months)
- COVID onset: Mar–Apr 2020 (2 months)
- Measure: conversion rate, AOV (average order value), category mix, session frequency
- Statistical test: two-proportion z-test on purchase conversion rate before vs after

---

## Data Quality Findings

Three significant data quality issues were surfaced during analysis. Each is documented here because they affect how results should be interpreted — and because real-world analytics work requires knowing what to do when data breaks.

---

### 1. Category Taxonomy Anomaly — `construction` ≠ DIY

**What was found:**
The raw category code `construction` ranked as the #1 revenue category at 49% of platform revenue (~1B out of ~2.06B). Its top three brands are Apple, Samsung, and Xiaomi — with Apple averaging $868 per purchase inside "DIY / Home Improvement." In October and November 2019, `construction` revenue was under $1.1M/month. In the week of December 2, 2019, it jumped to $35.3M in a single week — while `electronics` simultaneously collapsed from $36M to $3.7M/week. The switch was near-instantaneous.

**What this means:**
This is not a genuine DIY surge. Smartphones and consumer electronics that were previously tagged as `electronics` began appearing under `construction` starting December 2019 — a platform-side taxonomy event. The `construction` bucket functions as a misclassified electronics catch-all from December 2019 onward. The display name "DIY / Home Improvement" is misleading for this period.

**How it's handled:**
SQL queries and visualizations flag this explicitly. Category-level metrics treat `construction` as directional at best after December 2019. The data is not altered — the anomaly is disclosed, not corrected. Category analysis in Module 5 and Module 7 should be interpreted with this in mind.

---

### 2. Logging Gap — February 27, 2020

**What was found:**
On February 27, 2020, the platform logged 197,047 events. Every other day in the dataset averages 1.8–2.2 million events. This is a 90%+ drop. The 7-day rolling z-score is **-18.84** — physically impossible as organic human behavior. Approximately 1.8 million events are missing for that date.

**What this means:**
Something failed in the data collection pipeline on that day: a logging service crash, ingestion pipeline failure, or network partition. The data for February 27 is effectively absent from the dataset. It is not a real behavioral signal.

**How it's handled in analysis:**
February 27 is excluded from the Module 7 COVID quasi-experiment pre-period baseline via an explicit `WHERE DATE(event_time) != '2020-02-27'` filter. Including it would artificially lower the pre-COVID average and distort the before/after comparison.

**Real-world note:**
In a production environment, a gap of this magnitude would trigger an immediate escalation to the data engineering or platform operations team. An analyst's role is to surface and quantify the gap — root cause diagnosis (server crash, pipeline failure, infrastructure issue) belongs to the team that owns the logging infrastructure. In practice, the analyst would typically already be informed through incident reporting channels before discovering the anomaly in query output. The response is: flag it, scope the impact, exclude from affected analyses, and reference the incident ticket in documentation.

---

### 3. Platform Price Cap — $2,574.07

**What was found:**
IQR outlier analysis (Module 6) identified a hard ceiling on purchase prices across all major categories: exactly **$2,574.07**. All 100 flagged outlier transactions sit at or within $0.03 of this value — across electronics, appliances, computers, accessories, and construction. The maximum price in every major category is the same number.

**What this means:**
This is a platform-level price ceiling, not genuine price fraud or data error. The most likely mechanism: a round 1,000,000 Kazakhstani Tenge (KZT) transaction limit, converted to USD using the exchange rate in effect around October 2019 (~388.5 KZT/USD — very close to the real historical rate of ~383–390 KZT/USD for that period). This explanation is independently corroborated by a third party's separate analysis of this same dataset, which reports the identical minimum ($0.79) and maximum ($2,574.07) prices, and by other users on the dataset's own Kaggle discussion board who noticed this same anomaly years ago. The exact business mechanism behind the 1,000,000 KZT figure (a specific bank's transaction limit, an AML regulatory threshold, or an arbitrary round number chosen by the merchant's own systems) remains unconfirmed — see [`price_ceiling_research.md`](price_ceiling_research.md) for the full research trail, including claims that were checked and did *not* hold up. IQR outlier flags in this dataset reflect transactions hitting that ceiling, not anomalous pricing behavior. Outlier rates should be interpreted as "high-value transactions at the ceiling," not as suspicious activity.

A follow-up question was tested directly against the data: could $2,574.07 be only the *first installment* of a larger split payment, with the remainder unlogged elsewhere? `sql/06_anomaly_detection.sql` Query 6 checked whether the same user+product repeatedly hits the cap on a regular, installment-like cadence — it doesn't. Repeats cluster on the same day/session (consistent with buying multiple units in one order) or show irregular, unrelated gaps, not the evenly-spaced pattern an installment plan would produce. **$2,574.07 should be treated as the true, final recorded price, not a partial payment** (full test detail in `price_ceiling_research.md`).

**How it's handled:**
Outlier analysis in Module 6 documents this finding and adjusts interpretation accordingly. Price outlier counts by category remain useful for understanding which categories sell at maximum price points most frequently.

---

### 4. Funnel Floor Bias — No Raw Site-Visit Event

**What was found:**
This dataset's `events` table has exactly three `event_type` values: `view`, `cart`, `purchase` — every row is tied to a specific `product_id`. There is no event representing a generic site visit, a search, or homepage browsing that never touches a product page. A small gap confirms this: Module 2's total session count (89,693,595, counted from any event at all) is 213,976 sessions higher than Module 1's "sessions with a view" count (89,479,619) — meaning ~214K sessions have a cart or purchase event but zero logged product views.

**What this means:**
Every conversion rate reported in this project (6.09% overall, and all category/brand conversion rates) is measured **from first product view onward**, not from raw site arrival. There is an invisible layer of traffic above "viewed a product" — visitors who searched, browsed the homepage, or bounced without ever opening a product page — that this dataset cannot see or measure at all. The true top-of-funnel conversion rate (site arrival → purchase) is almost certainly lower than 6.09%, but it isn't computable from this data.

**How it's handled:**
This is a tracking-scope limitation, not a data error — REES46's tracking script is scoped to product-level interactions because that's what its core product (recommendations, cart-abandonment remarketing) needs, not general web analytics. The fix is interpretive, not corrective: every conversion metric in this repo should be read as "of people who engaged with a product, what fraction bought" — never as "of all site traffic."

---

## Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| Data warehouse | Google BigQuery | Primary query engine, 411M rows |
| Data loading | local CSV.gz → BigQuery | Monthly files loaded directly from local disk via `bq.cmd` |
| SQL | BigQuery SQL | CTEs, Window Functions, UNNEST, partitioning |
| Python | pandas, SciPy, matplotlib | RFM scoring, cohort matrix, statistical tests |
| Notebook | Jupyter / Google Colab | Reproducible analysis |
| BI | Power BI Desktop + Service | Report (.pbix) + live-alert Dashboard; Looker Studio optional |
| Reporting | Excel (openpyxl) | Stakeholder-facing workbook — same KPIs as Power BI, no tooling required |

---

## How to Start

**New to this project? Start here:**

1. Read `workflows/01_bigquery_setup.md` — BigQuery sandbox setup + dataset loading
2. Read `workflows/02_analytics_plan.md` — what to build, in what order, with what SQL patterns
3. Tools will be built during execution and stored in `tools/`

**Current state:** BigQuery loaded and verified — 411,709,736 events across 7 months. Modules 1–6 complete (Funnel, Session, RFM, Cohort Retention, Category & Brand, Anomaly Detection). Module 7 (COVID Quasi-Experiment) in progress.

---

## Portfolio Targeting

This project is designed to speak to roles that TechFlow cannot:

| Company type | What this project shows |
|---|---|
| Gaming / product analytics (Moon Active) | Event-level behavioral data, funnel analytics, session analysis |
| E-commerce platforms (Ashley Digital, Resident Home) | BigQuery SQL, behavioral segmentation, AI-assisted workflow |
| Consumer brands / CRM (Nespresso) | RFM segmentation, cohort retention, customer lifecycle |
| Fintech / fraud detection (Checkout.com) | Anomaly detection, behavioral risk signals |
| Any modern data stack company | BigQuery fluency, event table querying, cloud SQL |

Resume headline: *"Queried 411 million behavioral events in Google BigQuery — funnel analysis, cohort retention, RFM segmentation, and COVID-onset quasi-experiment on real e-commerce data."*
