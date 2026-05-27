# bigquery

Creates a BigQuery dataset and one or more tables.

## MiniSky compatibility

| Resource | Status | Notes |
|---|---|---|
| `google_bigquery_dataset` | ✓ | Full CRUD, synchronous |
| `google_bigquery_table` | ✓ | Full CRUD, synchronous |
| Dataset IAM | omitted | MiniSky BigQuery shim does not implement IAM |

## Real GCP additions

In real GCP, restore:
- `google_bigquery_dataset_iam_member` per role (dataEditor, dataViewer)
- `expiration_time` on tables for data lifecycle management
- `time_partitioning` and `clustering` on large event tables
- `google_bigquery_dataset_access` for cross-project access
