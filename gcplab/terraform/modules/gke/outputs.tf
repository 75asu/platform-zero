output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.this.name
}

output "cluster_id" {
  description = "Full resource ID of the cluster"
  value       = google_container_cluster.this.id
}

output "endpoint" {
  description = "IP address of the cluster master endpoint"
  value       = google_container_cluster.this.endpoint
}

output "location" {
  description = "Location where the cluster is deployed"
  value       = google_container_cluster.this.location
}
