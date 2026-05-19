variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project tag applied to all resources"
  type        = string
  default     = "platform-zero"
}

# ── Cluster sizing ─────────────────────────────────────────────────────────────

variable "node_type" {
  description = <<-EOT
    ElastiCache node type.
    Ministack: cache.t3.micro works.
    Real AWS minimum: cache.t3.micro (0.5 GiB, 2 vCPU).
    Prod recommendation: cache.r6g.large (13 GiB) for session-heavy SaaS.
  EOT
  type    = string
  default = "cache.t3.micro"
}

variable "engine_version" {
  description = "Redis engine version. 7.x supports ACL, Functions, and better memory management."
  type        = string
  default     = "7.0"
}

variable "parameter_group_name" {
  description = <<-EOT
    Redis parameter group. default.redis7 works for most workloads.
    Custom group needed if tuning maxmemory-policy (allkeys-lru for cache, noeviction for sessions).
  EOT
  type    = string
  default = "default.redis7"
}

# ── Networking ─────────────────────────────────────────────────────────────────

variable "create_subnet_group" {
  description = "Create ElastiCache subnet group. False for Ministack (no VPC)."
  type        = bool
  default     = false
}

variable "subnet_ids" {
  description = "Private subnet IDs for ElastiCache nodes. Empty for Ministack."
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Security group IDs controlling Redis port 6379 access. Empty for Ministack."
  type        = list(string)
  default     = []
}

# ── Backups and maintenance ────────────────────────────────────────────────────

variable "snapshot_retention_limit" {
  description = "Days to retain automatic snapshots. 0 = disabled (lab). 7+ for prod."
  type        = number
  default     = 0
}

variable "snapshot_window" {
  description = "Daily window for snapshots (hh:mm-hh:mm UTC). Must not overlap maintenance_window."
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Weekly window for maintenance (ddd:hh:mm-ddd:hh:mm UTC)."
  type        = string
  default     = "sun:05:00-sun:06:00"
}

variable "apply_immediately" {
  description = "Apply changes immediately vs next maintenance window. True in lab, false in prod."
  type        = bool
  default     = true
}
