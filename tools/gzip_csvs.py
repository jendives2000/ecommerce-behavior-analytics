"""
Compress raw CSV files in .tmp/raw_csvs/ into .tmp/gz_csvs/.
BigQuery accepts .csv.gz natively; gzipping reduces ~5 GB per file to ~1 GB,
speeding up GCS uploads and keeping storage within the free tier.

Usage:
    python tools/gzip_csvs.py
"""

import gzip
import shutil
from pathlib import Path

RAW_DIR = Path(".tmp/raw_csvs")
GZ_DIR = Path(".tmp/gz_csvs")

GZ_DIR.mkdir(parents=True, exist_ok=True)

csv_files = sorted(RAW_DIR.glob("*.csv"))
if not csv_files:
    print(f"No CSV files found in {RAW_DIR}. Run the Kaggle download first.")
    raise SystemExit(1)

for csv_file in csv_files:
    gz_path = GZ_DIR / (csv_file.name + ".gz")
    if gz_path.exists():
        print(f"  [SKIP] {gz_path.name} already exists")
        continue
    print(f"  Compressing {csv_file.name} ...", flush=True)
    with open(csv_file, "rb") as f_in, gzip.open(gz_path, "wb") as f_out:
        shutil.copyfileobj(f_in, f_out)
    size_mb = gz_path.stat().st_size // 1024 // 1024
    print(f"  -> {gz_path.name} ({size_mb} MB)")

print(f"\nDone. {len(csv_files)} file(s) processed. Output: {GZ_DIR}")
