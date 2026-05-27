locals {
  # BigQuery dataset IDs may only contain letters, numbers, and underscores.
  # Replace hyphens from the project/environment prefix before building the ID.
  dataset_id = replace("${var.project}_${var.environment}_${var.dataset_id}", "-", "_")
}

# ── Dataset ────────────────────────────────────────────────────────────────────

resource "google_bigquery_dataset" "this" {
  dataset_id = local.dataset_id
  project    = var.project_id
  location   = var.location

  # Delete dataset even if it still contains tables (safe for lab teardown).
  # In real GCP: remove this or set to false in production.
  delete_contents_on_destroy = true
}

# ── Tables ─────────────────────────────────────────────────────────────────────

resource "google_bigquery_table" "this" {
  for_each = var.tables

  dataset_id = google_bigquery_dataset.this.dataset_id
  table_id   = each.key
  project    = var.project_id

  # JSON schema string — array of field objects with name, type, mode.
  schema = each.value.schema

  deletion_protection = false
}

# ── IAM ────────────────────────────────────────────────────────────────────────
# MiniSky's BigQuery shim does not implement dataset-level IAM.
# In real GCP: add google_bigquery_dataset_iam_member to grant
# roles/bigquery.dataEditor to the app service account and
# roles/bigquery.dataViewer to the reader service account.
