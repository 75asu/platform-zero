variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "enabled" {
  description = <<-EOT
    When false, no ElastiCache resources are created. Use for Ministack/LocalStack labs
    where the provider waiter is incompatible with async container creation.
    Set to true for real AWS.
  EOT
  type    = bool
  default = false
}

variable "use_replication_group" {
  description = <<-EOT
    When true, use aws_elasticache_replication_group (production-correct — supports
    encryption, Multi-AZ, reader endpoint). When false, use aws_elasticache_cluster
    (single-node, works with Ministack/LocalStack for lab).
    Default false so lab environments work out of the box.
  EOT
  type    = bool
  default = false
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
    Lab: cache.t3.micro works.
    Real AWS minimum: cache.t3.micro (0.5 GiB, 2 vCPU).
    Prod recommendation: cache.r6g.large (13 GiB) for session-heavy SaaS.
  EOT
  type    = string
  default = "cache.t3.micro"
}

variable "num_cache_clusters" {
  description = <<-EOT
    Number of cache nodes in the replication group.
    1 = primary only (lab).
    2+ = primary + replicas (prod, required for automatic_failover_enabled).
  EOT
  type    = number
  default = 1
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
  description = "Create ElastiCache subnet group. False for lab emulators (no VPC)."
  type        = bool
  default     = false
}

variable "subnet_ids" {
  description = "Private subnet IDs for ElastiCache nodes. Empty for lab."
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Security group IDs controlling Redis port 6379 access. Empty for lab."
  type        = list(string)
  default     = []
}

# ── Encryption ─────────────────────────────────────────────────────────────────

variable "at_rest_encryption_enabled" {
  description = "Encrypt data at rest using KMS. Required for compliance. False in lab."
  type        = bool
  default     = false
}

variable "transit_encryption_enabled" {
  description = "Encrypt data in transit (TLS). Required for compliance. False in lab."
  type        = bool
  default     = false
}

# ── High availability ──────────────────────────────────────────────────────────

variable "automatic_failover_enabled" {
  description = "Enable automatic failover to a replica on primary failure. Requires num_cache_clusters >= 2."
  type        = bool
  default     = false
}

variable "multi_az_enabled" {
  description = "Enable Multi-AZ placement for the replication group. Requires automatic_failover_enabled."
  type        = bool
  default     = false
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
