output "service_name" {
  description = "Cloud Run service name"
  value       = google_cloud_run_v2_service.this.name
}

output "service_url" {
  description = "HTTPS URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.this.uri
}

output "service_id" {
  description = "Full resource ID of the Cloud Run service"
  value       = google_cloud_run_v2_service.this.id
}

output "latest_revision" {
  description = "Name of the latest revision created by this apply"
  value       = google_cloud_run_v2_service.this.latest_ready_revision
}
