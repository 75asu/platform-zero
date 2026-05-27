variable "project" {
  description = "Project name prefix used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the Cloud SQL instance"
  type        = string
  default     = "us-central1"
}

variable "database_version" {
  description = "Postgres version. POSTGRES_15 recommended for new deployments."
  type        = string
  default     = "POSTGRES_15"
}

variable "tier" {
  description = "Machine tier. db-f1-micro (dev), db-g1-small (staging), db-n1-standard-* (prod)."
  type        = string
  default     = "db-f1-micro"
}

variable "database_name" {
  description = "Name of the database to create within the instance"
  type        = string
  default     = "app"
}

variable "db_user" {
  description = "Database username for the application user"
  type        = string
  default     = "app"
}

variable "db_password" {
  description = "Database password for the application user"
  type        = string
  sensitive   = true
}

variable "database_flags" {
  description = "Map of Postgres configuration flags. Keys are flag names, values are strings."
  type        = map(string)
  default = {
    "max_connections" = "100"
    "log_min_duration_statement" = "1000"
  }
}

variable "backup_enabled" {
  description = "Enable automated daily backups. Set true for staging and prod."
  type        = bool
  default     = false
}
