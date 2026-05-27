output "instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.this.name
}

output "connection_name" {
  description = "Instance connection name used by Cloud SQL Proxy: project:region:instance"
  value       = google_sql_database_instance.this.connection_name
}

output "public_ip" {
  description = "Public IP address of the instance (ipv4_enabled = true)"
  value       = google_sql_database_instance.this.public_ip_address
}

output "database_name" {
  description = "Name of the application database"
  value       = google_sql_database.this.name
}

output "db_user" {
  description = "Application database username"
  value       = google_sql_user.app.name
}
