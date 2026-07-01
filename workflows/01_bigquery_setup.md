# Workflow: BigQuery Setup & Dataset Loading

## Objective
Get the REES46 dataset (7 monthly CSV files, ~411M events) into Google BigQuery so SQL queries can run against the full dataset.

## Prerequisites
- Google account (Gmail)
- ~50 GB local disk space for CSV downloads and gz files
- Python installed (for gzip compression step)
- Google Cloud SDK installed (`bq.cmd` CLI on Windows)
- **Billing enabled on the GCP project** (see Step 1 — this is required, not optional)

---

## Step 1: Create a GCP Project with Billing Enabled

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Sign in with your Google account
3. Click "Select a project" → "New Project" → name it anything consistent
4. Enable the BigQuery API if prompted
5. Go to Billing → Create a billing account → link it to the project

**Why billing is required (not optional):**
BigQuery Sandbox automatically bakes a 60-day partition expiration (`expirationMs: 5184000000`) into every partitioned table, even if you don't ask for it. Since the REES46 dataset contains data from 2019–2020, every partition is already 5+ years past its 60-day window. BigQuery accepts the load jobs (exit code 0, status DONE) but immediately treats all rows as expired — `COUNT(*)` returns 0. The only fix is to remove the expiration with `bq update --time_partitioning_expiration 0`, which requires billing to be enabled.

**Cost:** ~$0.54–$1.08/month for storage (~54 GB billed after 10 GB free tier). Queries stay within the 1 TB/month free tier for normal portfolio use. Set a budget alert at $3/month in Billing → Budgets & Alerts.

---

## Step 2: Download the Dataset from Kaggle

**Preferred path: Kaggle CLI**

1. Sign up / log in at [kaggle.com](https://www.kaggle.com)
2. Account → Create New API Token → downloads `kaggle.json`
3. Place `kaggle.json` in `~/.kaggle/kaggle.json` (already gitignored)
4. Run:

```bash
pip install kaggle
kaggle datasets download -d mkechinov/ecommerce-behavior-data-from-multi-category-store --unzip -p .tmp/raw_csvs/
```

Downloads and unzips all 7 monthly CSV files into `.tmp/raw_csvs/`. Total: ~35–40 GB.

**Fallback: browser download**

Dataset: [ecommerce-behavior-data-from-multi-category-store](https://www.kaggle.com/datasets/mkechinov/ecommerce-behavior-data-from-multi-category-store)

Download all 7 files and place in `.tmp/raw_csvs/`:

- `2019-Oct.csv`, `2019-Nov.csv`, `2019-Dec.csv`
- `2020-Jan.csv`, `2020-Feb.csv`, `2020-Mar.csv`, `2020-Apr.csv`

> `.tmp/` is gitignored. These files are your permanent local source of truth. Do not delete them until the project is fully exported and wrapped.

---

## Step 3: Gzip the CSV Files

BigQuery accepts `.csv.gz` natively. Gzipping reduces file size ~5x and speeds up loading.

```bash
python tools/gzip_csvs.py
```

Reads from `.tmp/raw_csvs/`, writes compressed files to `.tmp/gz_csvs/`. Already-compressed files are skipped.

---

## Step 4: Configure Your Environment

Open `.env` and fill in:

```bash
GCP_PROJECT_ID=your-project-id
BQ_DATASET=rees46
BQ_TABLE=events
```

---

## Step 5: Create the BigQuery Dataset and Table

Run in Cloud Shell or locally with `bq.cmd` (Windows):

**Create dataset:**
```bash
bq --location=US mk instant-form-500912-n7:rees46
```

**Create table — partitioned by event_time, clustered by event_type:**
```bash
bq mk --table \
  --schema 'event_time:TIMESTAMP,event_type:STRING,product_id:INTEGER,category_id:INTEGER,category_code:STRING,brand:STRING,price:FLOAT,user_id:INTEGER,user_session:STRING' \
  --time_partitioning_type=DAY \
  --time_partitioning_field=event_time \
  --clustering_fields=event_type \
  instant-form-500912-n7:rees46.events
```

**⚠️ Critical — remove the Sandbox partition expiration immediately after table creation:**
```bash
bq update --time_partitioning_expiration 0 instant-form-500912-n7:rees46.events
```

This must be done before any data is loaded. If you skip this step, all loads appear to succeed but `COUNT(*)` returns 0 because every 2019–2020 partition is already past the 60-day expiry window.

**Verify the table is clean before loading:**

```bash
bq show --format=prettyjson instant-form-500912-n7:rees46.events
```

Check that `timePartitioning` has NO `expirationMs` field, and `event_time` type is `TIMESTAMP`.

---

## Step 6: Load All Monthly Files

Load directly from local `.csv.gz` files — no GCS bucket needed.

**Windows PowerShell script** (save as `bq_load_all.ps1`):

```powershell
$sdkBin = "C:\Users\<you>\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin"
$env:PATH = "$sdkBin;" + $env:PATH
$dataDir = "<project-root>\.tmp\gz_csvs"
$table = "instant-form-500912-n7:rees46.events"

$months = @(
    @{ label = "October 2019";   file = "2019-Oct.csv.gz" },
    @{ label = "November 2019";  file = "2019-Nov.csv.gz" },
    @{ label = "December 2019";  file = "2019-Dec.csv.gz" },
    @{ label = "January 2020";   file = "2020-Jan.csv.gz" },
    @{ label = "February 2020";  file = "2020-Feb.csv.gz" },
    @{ label = "March 2020";     file = "2020-Mar.csv.gz" },
    @{ label = "April 2020";     file = "2020-Apr.csv.gz" }
)

foreach ($month in $months) {
    $filePath = "$dataDir\$($month.file)"
    Write-Output "=== Loading $($month.label) ==="
    Write-Output "Start: $(Get-Date -Format 'HH:mm:ss')"

    & "$sdkBin\bq.cmd" load `
        --location=US `
        --source_format=CSV `
        --skip_leading_rows=1 `
        --allow_quoted_newlines `
        $table `
        $filePath 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Output "$($month.label) - SUCCESS at $(Get-Date -Format 'HH:mm:ss')"
    } else {
        Write-Output "$($month.label) - FAILED (exit $LASTEXITCODE). Stopping."
        exit 1
    }
}
```

**Key rules for `bq load`:**

- Use `bq.cmd` on Windows, not `bq` (the bare command silently exits 0 without doing anything)
- Always pass `--location=US`
- Do NOT pass a schema argument — when the table already exists, passing schema causes "Cannot replace a table with a different partitioning spec" error
- Do NOT pass `--replace` — each load appends to the existing table
- Each month takes ~25–30 minutes

---

## Step 7: Verify the Load

Run in BigQuery Studio:

```sql
-- Row count by month
SELECT
  FORMAT_DATE('%Y-%m', DATE(event_time)) AS month,
  COUNT(*) AS cnt
FROM `instant-form-500912-n7.rees46.events`
GROUP BY month
ORDER BY month;
```

**Expected output (actual verified counts):**

| month       | cnt             |
|-------------|-----------------|
| 2019-10     | 42,448,764      |
| 2019-11     | 67,501,979      |
| 2019-12     | 67,542,878      |
| 2020-01     | 55,967,041      |
| 2020-02     | 55,318,565      |
| 2020-03     | 56,341,241      |
| 2020-04     | 66,589,268      |
| **Total**   | **411,709,736** |

If `COUNT(*)` returns 0 despite successful load jobs, the partition expiration was not removed. Fix: run `bq update --time_partitioning_expiration 0 instant-form-500912-n7:rees46.events` — no reload needed, rows become visible immediately.

```sql
-- Event type distribution
SELECT
  event_type,
  COUNT(*) AS cnt,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct
FROM `instant-form-500912-n7.rees46.events`
GROUP BY event_type
ORDER BY cnt DESC;
```

---

## Step 8: Cost-Conscious Query Habits

BigQuery charges by bytes scanned. The 1 TB/month free tier covers normal portfolio use comfortably.

**Use partition + cluster pruning:**
```sql
SELECT event_type, user_id, price
FROM `instant-form-500912-n7.rees46.events`
WHERE DATE(event_time) BETWEEN '2019-10-01' AND '2019-10-31'  -- partition pruning
  AND event_type = 'purchase'                                   -- cluster pruning
```

**Avoid full table scans:** Check estimated bytes in BigQuery Studio before running. A full scan of all 411M rows costs ~46 GB against your 1 TB quota.

---

## Known Issues / Gotchas

- **Sandbox partition expiration:** If you recreate the table while still in Sandbox mode, the 60-day expiration returns. Always run `bq update --time_partitioning_expiration 0` after any `bq mk --table` on a partitioned table.
- **`bq` vs `bq.cmd` on Windows:** The bare `bq` command in PowerShell silently exits 0 without executing. Always use the full path to `bq.cmd`.
- **Schema argument on existing tables:** Passing a schema string to `bq load` when the table already exists triggers "Cannot replace a table with a different partitioning spec". Omit the schema — BigQuery uses the existing table schema.
- **`category_code` NULLs:** Handle with `COALESCE(category_code, 'unknown')` in queries.
- **`price = 0.0`:** Filter with `WHERE price > 0` for revenue analysis.
- **`user_session` is UUID:** Group by `user_session`, not `user_id`, for session-level analysis.
- **60-day table expiry in Sandbox (project-level):** With billing enabled this no longer applies. If you ever revert to Sandbox, tables expire 60 days after last use — re-load from local gz files if needed.

---

## Next Step

All 7 months loaded and verified → read `workflows/02_analytics_plan.md` and begin Module 1: Funnel Analysis.
