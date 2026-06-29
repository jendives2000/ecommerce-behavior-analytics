# E-Commerce Behavior Analytics

> **285 million real behavioral events. One question: what separates a browser from a buyer?**
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
| **Project 2 — This project** | REES46 (285M events) | E-commerce behavior | Funnel, retention cohorts, RFM, anomaly detection |

Project 1 speaks to fintech/B2B SaaS roles. This project speaks to product analytics, gaming, e-commerce, and modern data stack roles — specifically the gap companies like Moon Active, Ashley Digital, and Nespresso represent in the Israeli job market.

The key portfolio signal: **event-level behavioral data in BigQuery**. GA4, Amplitude, and Mixpanel all produce the same structure (event_time, event_type, user_id, session_id). Knowing how to query it is the transferable skill.

---

## Dataset

**Source:** [eCommerce Behavior Data from Multi Category Store](https://www.kaggle.com/datasets/mkechinov/ecommerce-behavior-data-from-multi-category-store) — Kaggle / REES46 Open CDP

**Nature:** Real behavioral event data from a large live e-commerce platform. Collected by REES46 Marketing Platform. Attribution required when using.

**Scale:** 285 million events across 7 months (October 2019 – April 2020)

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

**Time span significance:** Oct 2019 – Feb 2020 = pre-COVID baseline. Mar–Apr 2020 = COVID-onset period. Natural quasi-experiment baked into the data.

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

## Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| Data warehouse | Google BigQuery | Primary query engine, 285M rows |
| Data loading | GCS → BigQuery | Monthly CSV files staged via Cloud Storage |
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

**Current state:** Project initialized. Workflows written. BigQuery not yet set up. Dataset not yet loaded. Ready to kick off.

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

Resume headline: *"Queried 285 million behavioral events in Google BigQuery — funnel analysis, cohort retention, RFM segmentation, and COVID-onset quasi-experiment on real e-commerce data."*
