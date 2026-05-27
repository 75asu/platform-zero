output "dataset_id" {
  description = "BigQuery dataset ID"
  value       = google_bigquery_dataset.this.dataset_id
}

output "dataset_self_link" {
  description = "URI of the dataset"
  value       = google_bigquery_dataset.this.self_link
}

output "table_ids" {
  description = "Map of table_id key to fully qualified table ID (project:dataset.table)"
  value       = { for k, v in google_bigquery_table.this : k => v.id }
}
