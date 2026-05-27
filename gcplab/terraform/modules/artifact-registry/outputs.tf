output "repository_id" {
  description = "Short repository ID"
  value       = google_artifact_registry_repository.this.repository_id
}

output "repository_name" {
  description = "Full repository resource name"
  value       = google_artifact_registry_repository.this.name
}

output "docker_registry_url" {
  description = "Docker registry base URL for pushing/pulling images: {location}-docker.pkg.dev/{project}/{repository}"
  value       = "${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.this.repository_id}"
}
