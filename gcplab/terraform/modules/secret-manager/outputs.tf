output "secret_ids" {
  description = "Map of secret short name to full secret ID (projects/{project}/secrets/{secret_id})"
  value       = { for k, v in google_secret_manager_secret.this : k => v.id }
}

output "secret_names" {
  description = "Map of secret short name to secret_id string (used in IAM bindings and API calls)"
  value       = { for k, v in google_secret_manager_secret.this : k => v.secret_id }
}
