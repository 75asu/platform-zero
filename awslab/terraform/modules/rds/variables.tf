variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project tag applied to all resources"
  type        = string
  default     = "platform-zero"
}

# ── Engine ─────────────────────────────────────────────────────────────────────

variable "engine" {
  description = "Database engine. Only postgres tested in this lab."
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "Major.minor engine version (e.g. '14', '14.10', '16.2')"
  type        = string
  default     = "14"
}

variable "parameter_group_family" {
  description = "Parameter group family. Must match the engine major version (e.g. 'postgres14')."
  type        = string
  default     = "postgres14"
}

# ── Instance ───────────────────────────────────────────────────────────────────

variable "instance_class" {
  description = <<-EOT
    RDS instance class.
    db.t3.micro: 2 vCPU, 1 GiB — fine for dev/staging.
    db.r6g.*: memory-optimised — production Postgres under load.
  EOT
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Initial storage in GiB. gp2/gp3 storage autoscales above this floor."
  type        = number
  default     = 20
}

variable "storage_type" {
  description = "gp3 is current-gen (cheaper IOPS), gp2 is legacy. Use gp3 for new instances."
  type        = string
  default     = "gp2" # Ministack compatibility — gp3 may not be recognised
}

variable "storage_encrypted" {
  description = "Encrypt storage at rest using KMS. Set false for Ministack (no KMS support)."
  type        = bool
  default     = false
}

# ── Credentials ────────────────────────────────────────────────────────────────

variable "db_name" {
  description = "Name of the initial database created on the instance."
  type        = string
  default     = "app"
}

variable "db_username" {
  description = "Master DB username."
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = <<-EOT
    Master DB password. Sensitive — never commit real values.
    In real AWS: generate via aws_secretsmanager_random_password or pass from CI env.
  EOT
  type      = string
  sensitive = true
}

# ── Availability ───────────────────────────────────────────────────────────────

variable "multi_az" {
  description = <<-EOT
    Enable Multi-AZ standby replica.
    Automatic failover in ~60-120s if primary AZ fails. Doubles cost.
    Always true in prod, false in dev/staging lab.
  EOT
  type    = bool
  default = false
}

variable "backup_retention_period" {
  description = "Days to retain automated backups. 0 disables backups (also disables PITR). Min 7 for prod."
  type        = number
  default     = 7
}

variable "apply_immediately" {
  description = "Apply changes immediately vs next maintenance window. Always true in lab environments."
  type        = bool
  default     = true
}

# ── Lifecycle ──────────────────────────────────────────────────────────────────

variable "deletion_protection" {
  description = "Prevent accidental deletion via Terraform. Always true in prod."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy. Set false in prod to retain a restore point."
  type        = bool
  default     = true
}

# ── Networking ─────────────────────────────────────────────────────────────────

variable "create_subnet_group" {
  description = <<-EOT
    Create a DB subnet group from subnet_ids.
    Set false for Ministack (no VPC support) — uses Ministack's internal default.
    Set true in real AWS and provide subnet_ids from the VPC module.
  EOT
  type    = bool
  default = false
}

variable "subnet_ids" {
  description = "Subnet IDs for the DB subnet group. Required when create_subnet_group = true."
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "Security group IDs to attach. Empty list = Ministack default (no restriction)."
  type        = list(string)
  default     = []
}

# ── Parameter group tuning ─────────────────────────────────────────────────────

variable "max_connections" {
  description = <<-EOT
    Maximum concurrent DB connections.
    Rule of thumb: (RAM_GB * 1000) / connection_overhead_MB.
    Default 100 is conservative for db.t3.micro (1 GiB RAM).
    Use RDS Proxy in prod to pool connections and avoid this ceiling.
  EOT
  type    = string
  default = "100"
}

variable "log_min_duration_statement" {
  description = <<-EOT
    Log any SQL statement taking longer than this many milliseconds.
    -1 disables slow query logging. 1000 = 1 second threshold.
    Lower in staging (500) to catch marginal queries before prod.
  EOT
  type    = string
  default = "1000"
}
