# Workflow: BigQuery Setup & Dataset Loading

## Objective
Get the REES46 dataset (285M events, 7 monthly CSV files) into Google BigQuery sandbox so SQL queries can run against the full dataset. No credit card required.

## Prerequisites
- Google account (Gmail)
- ~40 GB local disk space for CSV downloads
- Python installed (for optional gzip compression step)

---

## Step 1: Create BigQuery Sandbox Project

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Sign in with Google account
3. Click "Select a project" → "New Project"
4. Name it: `ecommerce-behavior-analytics` (or any name)
5. In the left sidebar: BigQuery → Enable the API if prompted
6. You are now in BigQuery Sandbox mode — no billing account, no credit card

**Verify:** You should see the BigQuery Studio interface with a query editor. The project appears in the Explorer panel on the left.

---

## Step 2: Download the Dataset from Kaggle

Dataset URL: https://www.kaggle.com/datasets/mkechinov/ecommerce-behavior-data-from-multi-category-store

**Download all 7 monthly files:**
- `2019-Oct.csv`
- `2019-Nov.csv`
- `2019-Dec.csv`
- `2020-Jan.csv`
- `2020-Feb.csv`
- `2020-Mar.csv`
- `2020-Apr.csv`

Each file is ~5–6 GB. Total download: ~35–40 GB. Kaggle requires a free account to download.

**Kaggle CLI (faster than browser):**
```bash
pip install kaggle
kaggle datasets download mkechinov/ecommerce-behavior-data-from-multi-category-store
```

Store downloaded files in: `.tmp/raw_csvs/`

---

## Step 3: (Optional but recommended) Gzip the CSV files

BigQuery accepts `.csv.gz` natively. Gzipping reduces file size ~5x (5 GB → ~1 GB), which speeds up GCS upload and reduces storage cost.

```python
# tools/gzip_csvs.py — run once after download
import gzip, shutil
from pathlib import Path

raw_dir = Path(".tmp/raw_csvs")
gz_dir = Path(".tmp/gz_csvs")
gz_dir.mkdir(exist_ok=True)

for csv_file in sorted(raw_dir.glob("*.csv")):
    gz_path = gz_dir / (csv_file.name + ".gz")
    if gz_path.exists():
        print(f"  [SKIP] {gz_path.name}")
        continue
    print(f"  Compressing {csv_file.name} ...", flush=True)
    with open(csv_file, "rb") as f_in, gzip.open(gz_path, "wb") as f_out:
        shutil.copyfileobj(f_in, f_out)
    print(f"  -> {gz_path.name} ({gz_path.stat().st_size // 1024 // 1024} MB)", flush=True)
```

---

## Step 4: Create a GCS Bucket (staging area)

GCS = Google Cloud Storage. BigQuery loads large files via GCS, not direct upload.

1. In the Cloud Console left sidebar: Cloud Storage → Buckets → Create
2. Name: `rees46-staging-<your-initials>` (must be globally unique)
3. Region: `us-central1` (same region as BigQuery to avoid egress costs)
4. Storage class: Standard
5. Leave all other settings default → Create

**Free tier:** 5 GB free storage in US region. Since each gz file is ~1 GB, load one file at a time and delete from GCS after loading into BigQuery to stay in free tier.

---

## Step 5: Create the BigQuery Dataset and Table Schema

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
- Both reduce bytes scanned = stay within 1 TB/month free tier

---

## Step 6: Load Each Monthly File

Repeat for each of the 7 months. Load one at a time.

**Upload gz file to GCS:**
```bash
gsutil cp .tmp/gz_csvs/2019-Oct.csv.gz gs://rees46-staging-jyt/
```

**Load from GCS into BigQuery:**
```bash
bq load \
  --source_format=CSV \
  --skip_leading_rows=1 \
  --allow_quoted_newlines \
  --time_partitioning_field=event_time \
  ecommerce-behavior-analytics:rees46.events \
  gs://rees46-staging-jyt/2019-Oct.csv.gz \
  event_time:TIMESTAMP,event_type:STRING,product_id:INTEGER,category_id:INTEGER,category_code:STRING,brand:STRING,price:FLOAT,user_id:INTEGER,user_session:STRING
```

**After successful load: delete from GCS to free storage:**
```bash
gsutil rm gs://rees46-staging-jyt/2019-Oct.csv.gz
```

Repeat for all 7 files.

**Alternative: BigQuery UI load (no CLI)**
- Open the `rees46.events` table in BigQuery Studio
- Click "+" → Upload → Select file from GCS
- Format: CSV, skip 1 header row, partition field: event_time

---

## Step 7: Verify the Load

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

## Step 8: Cost-Conscious Query Habits

BigQuery charges by bytes scanned. The 1 TB/month free tier is generous but not infinite.

**Always do:**
```sql
-- SELECT only the columns you need
SELECT event_type, user_id, price
FROM `ecommerce-behavior-analytics.rees46.events`
WHERE DATE(event_time) BETWEEN '2019-10-01' AND '2019-10-31'  -- uses partition pruning
  AND event_type = 'purchase'  -- uses cluster pruning
```

**Never do (unless you need to):**
```sql
SELECT * FROM `ecommerce-behavior-analytics.rees46.events`  -- scans all columns
```

**Check bytes before running:** BigQuery shows estimated bytes scanned before execution. If it looks high, add more `WHERE` filters.

---

## Known Issues / Gotchas

- `category_code` contains NULLs for some products — handle with `COALESCE(category_code, 'unknown')` in queries
- Some `price` values are 0.0 — likely internal events or data quality issues, filter with `WHERE price > 0` for revenue analysis
- `user_session` is a UUID string — for session-level analysis, group by `user_session`, not by `user_id`
- Sandbox tables expire after 60 days — if the table is deleted, re-load from local gz files (they're the source of truth)

---

## Next Step

Once all 7 files are loaded and verified → read `workflows/02_analytics_plan.md`
