output "db_endpoint" {
  description = "Full host:port endpoint of the DB instance"
  value       = aws_db_instance.this.endpoint
}

output "db_host" {
  description = "Hostname of the DB instance — use this in connection strings"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Port the DB listens on (5432 for Postgres)"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Name of the initial database"
  value       = aws_db_instance.this.db_name
}

output "db_username" {
  description = "Master DB username"
  value       = aws_db_instance.this.username
}

output "db_identifier" {
  description = "RDS instance identifier — used in CLI commands and console"
  value       = aws_db_instance.this.identifier
}

output "parameter_group_name" {
  description = "Name of the custom parameter group — reference when adding read replicas"
  value       = aws_db_parameter_group.this.name
}

output "secret_arn" {
  description = "Secrets Manager ARN for DB credentials — grant GetSecretValue to app roles"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "secret_name" {
  description = "Secrets Manager secret name — used in AWS CLI and SDK lookups"
  value       = aws_secretsmanager_secret.db_credentials.name
}
