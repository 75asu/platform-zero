locals {
  name = "${var.project}-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# ── Subnet group ───────────────────────────────────────────────────────────────
# Tells ElastiCache which VPC subnets to place nodes in.
# Always private subnets — Redis must not be publicly reachable.
# Ministack: set create_subnet_group = false (no VPC support).
resource "aws_elasticache_subnet_group" "this" {
  count = var.create_subnet_group ? 1 : 0

  name        = local.name
  subnet_ids  = var.subnet_ids
  description = "ElastiCache subnet group for ${local.name}"

  tags = merge(local.common_tags, {
    Name = local.name
  })
}

# ── Redis cluster ──────────────────────────────────────────────────────────────
# Single-node Redis for session state and caching.
#
# Lab vs Prod distinction (important for interviews):
#   Lab (this module): aws_elasticache_cluster — single node, simpler API, no encryption.
#   Prod: aws_elasticache_replication_group — supports:
#     - at_rest_encryption_enabled = true (KMS CMK)
#     - transit_encryption_enabled = true (TLS)
#     - num_cache_clusters = 2+ (primary + replica, Multi-AZ failover)
#     - reader_endpoint_address (separate endpoint for read-only queries)
#     - automatic failover on primary failure (~30s promotion time)
#   Switch to replication group when moving to real AWS.
resource "aws_elasticache_cluster" "this" {
  cluster_id        = local.name
  engine            = "redis"
  node_type         = var.node_type
  num_cache_nodes   = 1
  engine_version    = var.engine_version
  port              = 6379
  parameter_group_name = var.parameter_group_name

  subnet_group_name  = var.create_subnet_group ? aws_elasticache_subnet_group.this[0].name : null
  security_group_ids = length(var.security_group_ids) > 0 ? var.security_group_ids : null

  # Automatic daily backups. 0 = disabled (lab default, speeds up destroy).
  # Prod: snapshot_retention_limit = 7+ gives you PITR within the window.
  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window          = var.snapshot_window
  maintenance_window       = var.maintenance_window

  apply_immediately = var.apply_immediately

  tags = merge(local.common_tags, {
    Name = local.name
  })
}
