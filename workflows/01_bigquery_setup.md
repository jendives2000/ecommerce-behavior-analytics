# Workflow: BigQuery Setup & Dataset Loading

## Objective
Get the REES46 dataset (285M events, 7 monthly CSV files) into Google BigQuery sandbox so SQL queries can run against the full dataset. No credit card required.

## Prerequisites
- Google account (Gmail)
- ~40 GB local disk space for CSV downloads
- Python installed (for gzip compression step)
- Google Cloud SDK installed (for the `bq` CLI command)

---

## Step 1: Create BigQuery Sandbox Project

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Sign in with your Google account
3. Click "Select a project" → "New Project"
4. Name it: `ecommerce-behavior-analytics` (or any name — just keep it consistent with your `.env`)
5. In the left sidebar: BigQuery → Enable the API if prompted
6. You are now in BigQuery Sandbox mode — no billing account, no credit card

**Verify:** You should see the BigQuery Studio interface with a query editor. The project appears in the Explorer panel on the left.

---

## Step 2: Download the Dataset from Kaggle

**Preferred path: Kaggle CLI (faster, resumable, no size limits)**

1. Sign up / log in at [kaggle.com](https://www.kaggle.com)
2. Go to Account → Create New API Token → downloads `kaggle.json`
3. Place `kaggle.json` in `~/.kaggle/kaggle.json` (already gitignored)
4. Run:

```bash
pip install kaggle
kaggle datasets download -d mkechinov/ecommerce-behavior-data-from-multi-category-store --unzip -p .tmp/raw_csvs/
```

This downloads and unzips all 7 monthly CSV files directly into `.tmp/raw_csvs/`. Total download: ~35–40 GB.

**Fallback: browser download**

Dataset URL: https://www.kaggle.com/datasets/mkechinov/ecommerce-behavior-data-from-multi-category-store

Download all 7 monthly files manually and place them in `.tmp/raw_csvs/`:
- `2019-Oct.csv`
- `2019-Nov.csv`
- `2019-Dec.csv`
- `2020-Jan.csv`
- `2020-Feb.csv`
- `2020-Mar.csv`
- `2020-Apr.csv`

> **Note:** `.tmp/` is gitignored. These files never touch the repo and are your permanent local source of truth. Do not delete them until the entire project is exported and wrapped.

---

## Step 3: Gzip the CSV Files

BigQuery accepts `.csv.gz` natively. Gzipping reduces file size ~5x (5 GB → ~1 GB per file), which speeds up GCS upload and reduces storage cost.

Run the dedicated tool:

```bash
python tools/gzip_csvs.py
```

This reads from `.tmp/raw_csvs/` and writes compressed files to `.tmp/gz_csvs/`. Already-compressed files are skipped automatically.

---

## Step 4: Configure Your Environment

Open `.env` and fill in:

```bash
GCP_PROJECT_ID=ecommerce-behavior-analytics
BQ_DATASET=rees46
BQ_TABLE=events
```

---

## Step 5: ~~Create a GCS Bucket~~ — SKIPPED

GCS requires billing to be enabled even for the free tier. Since the GCP free trial has ended and billing is off, we skip GCS entirely and load directly from local gz files in Step 7. No bucket needed.

---

## Step 6: Create the BigQuery Dataset and Table Schema

In BigQuery Studio, run this DDL once to create the target table:

```sql
CREATE OR REPLACE TABLE `ecommerce-behavior-analytics.rees46.events`
(
  event_time    TIMESTAMP,
  event_type    STRING,
  product_id    INT64,
  category_id   INT64,
  category_code STRING,
  brand         STRING,
  price         FLOAT64,
  user_id       INT64,
  user_session  STRING
)
PARTITION BY DATE(event_time)
CLUSTER BY event_type;
```

**Why partition + cluster:**
- `PARTITION BY DATE(event_time)` — queries filtered by date scan only relevant partitions, saving TB quota
- `CLUSTER BY event_type` — queries filtered on `event_type = 'purchase'` are faster
- Both reduce bytes scanned = stay within the 1 TB/month free tier

---

## Step 7: Load Each Monthly File (CLI — Primary Path)

Repeat for each of the 7 months. Load one file at a time to stay within GCS free tier.

**Upload gz file to GCS:**
```bash
gsutil cp .tmp/gz_csvs/2019-Oct.csv.gz gs://rees46-staging-<your-initials>/
```

**Load from GCS into BigQuery:**
```bash
bq load \
  --source_format=CSV \
  --skip_leading_rows=1 \
  --allow_quoted_newlines \
  --time_partitioning_field=event_time \
  ecommerce-behavior-analytics:rees46.events \
  gs://rees46-staging-<your-initials>/2019-Oct.csv.gz \
  event_time:TIMESTAMP,event_type:STRING,product_id:INTEGER,category_id:INTEGER,category_code:STRING,brand:STRING,price:FLOAT,user_id:INTEGER,user_session:STRING
```

**After successful load — delete from GCS to free storage:**
```bash
gsutil rm gs://rees46-staging-<your-initials>/2019-Oct.csv.gz
```

Repeat for all 7 files in order.

**Fallback: BigQuery UI load**
- Open the `rees46.events` table in BigQuery Studio
- Click "+" → Upload → Select file from GCS
- Format: CSV, skip 1 header row, partition field: event_time

---

## Step 8: Verify the Load

Run these verification queries after loading all files:

```sql
-- Row count by month (should be ~285M total across 7 months)
SELECT
  FORMAT_DATE('%Y-%m', DATE(event_time)) AS month,
  COUNT(*) AS event_count
FROM `ecommerce-behavior-analytics.rees46.events`
GROUP BY month
ORDER BY month;

-- Event type distribution
SELECT
  event_type,
  COUNT(*) AS count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct
FROM `ecommerce-behavior-analytics.rees46.events`
GROUP BY event_type;

-- Sample rows
SELECT * FROM `ecommerce-behavior-analytics.rees46.events` LIMIT 10;
```

**Expected approximate distribution:**
- `view`: ~75–80% of events
- `cart`: ~15–18% of events
- `purchase`: ~5–7% of events

---

## Step 9: Cost-Conscious Query Habits

BigQuery charges by bytes scanned. The 1 TB/month free tier is generous but not infinite.

**Always do:**
```sql
-- SELECT only the columns you need, and filter on partitioned/clustered columns
SELECT event_type, user_id, price
FROM `ecommerce-behavior-analytics.rees46.events`
WHERE DATE(event_time) BETWEEN '2019-10-01' AND '2019-10-31'  -- partition pruning
  AND event_type = 'purchase'                                   -- cluster pruning
```

**Never do (unless you need to):**
```sql
SELECT * FROM `ecommerce-behavior-analytics.rees46.events`  -- scans all columns, all partitions
```

**Check bytes before running:** BigQuery shows estimated bytes scanned before execution. If it looks high, add more `WHERE` filters.

---

## Known Issues / Gotchas

- `category_code` contains NULLs for some products — handle with `COALESCE(category_code, 'unknown')` in queries
- Some `price` values are 0.0 — likely internal events or data quality issues, filter with `WHERE price > 0` for revenue analysis
- `user_session` is a UUID string — for session-level analysis, group by `user_session`, not by `user_id`
- **Sandbox tables expire after 60 days of inactivity** — if a table is deleted, re-load from your local gz files (they are the source of truth). Your portfolio artifacts (SQL files, notebooks with saved outputs, Excel workbook, Power BI .pbix in Import mode) are not affected by table expiry — they are self-contained.

---

## Next Step

Once all 7 files are loaded and verified → read `workflows/02_analytics_plan.md`
