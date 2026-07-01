"""
Load a monthly REES46 gz CSV file into BigQuery.
Uses explicit STRING schema for event_time to prevent BigQuery Sandbox
from auto-promoting TIMESTAMP columns and applying 60-day partition expiry
(which silently drops all 2019/2020 historical data).

Usage:
    python tools/bq_load.py <path_to_gz_file>

Example:
    python tools/bq_load.py .tmp/gz_csvs/2019-Oct.csv.gz
"""

import sys
import os
from google.cloud import bigquery
from google.api_core.exceptions import Conflict

PROJECT_ID = "instant-form-500912-n7"
DATASET_ID = "rees46"
TABLE_ID = "events"
TABLE_REF = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"

# event_time stored as STRING — prevents BigQuery Sandbox auto-partition
# In SQL queries use: TIMESTAMP(event_time) or PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S UTC', event_time)
SCHEMA = [
    bigquery.SchemaField("event_time",    "STRING"),
    bigquery.SchemaField("event_type",    "STRING"),
    bigquery.SchemaField("product_id",    "INTEGER"),
    bigquery.SchemaField("category_id",   "INTEGER"),
    bigquery.SchemaField("category_code", "STRING"),
    bigquery.SchemaField("brand",         "STRING"),
    bigquery.SchemaField("price",         "FLOAT"),
    bigquery.SchemaField("user_id",       "INTEGER"),
    bigquery.SchemaField("user_session",  "STRING"),
]


def ensure_table(client):
    dataset_ref = client.dataset(DATASET_ID)
    try:
        client.get_dataset(dataset_ref)
    except Exception:
        client.create_dataset(bigquery.Dataset(dataset_ref))
        print(f"Created dataset {DATASET_ID}")

    table_ref = client.dataset(DATASET_ID).table(TABLE_ID)
    table = bigquery.Table(table_ref, schema=SCHEMA)
    try:
        client.get_table(table_ref)
        print(f"Table {TABLE_REF} already exists — appending")
    except Exception:
        client.create_table(table)
        print(f"Created table {TABLE_REF}")


def load_file(client, gz_path):
    if not os.path.exists(gz_path):
        print(f"ERROR: File not found: {gz_path}")
        sys.exit(1)

    print(f"Loading {gz_path} → {TABLE_REF} ...")

    job_config = bigquery.LoadJobConfig(
        schema=SCHEMA,
        source_format=bigquery.SourceFormat.CSV,
        skip_leading_rows=1,
        allow_quoted_newlines=True,
        autodetect=False,
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
    )

    with open(gz_path, "rb") as f:
        job = client.load_table_from_file(f, TABLE_REF, job_config=job_config)

    print(f"Job {job.job_id} started, waiting ...")
    job.result()

    table = client.get_table(TABLE_REF)
    print(f"Done. Table now has {table.num_rows:,} rows.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)

    gz_path = sys.argv[1]
    client = bigquery.Client(project=PROJECT_ID)
    ensure_table(client)
    load_file(client, gz_path)
