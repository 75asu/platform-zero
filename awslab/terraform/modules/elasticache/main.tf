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
# Lab (Ministack): set create_subnet_group = false.
resource "aws_elasticache_subnet_group" "this" {
  count = var.enabled && var.create_subnet_group ? 1 : 0

  name        = local.name
  subnet_ids  = var.subnet_ids
  description = "ElastiCache subnet group for ${local.name}"

  tags = merge(local.common_tags, {
    Name = local.name
  })
}

# ── Redis replication group (production) ───────────────────────────────────────
# ReplicationGroup is the production-correct resource.
# Supports encryption at rest (KMS CMK), TLS in transit, Multi-AZ failover,
# and a separate reader endpoint.
# Set use_replication_group = true in production.
resource "aws_elasticache_replication_group" "this" {
  count = var.enabled && var.use_replication_group ? 1 : 0

  replication_group_id = local.name
  description          = "Redis replication group for ${local.name}"

  engine               = "redis"
  node_type            = var.node_type
  num_cache_clusters   = var.num_cache_clusters
  engine_version       = var.engine_version
  port                 = 6379
  parameter_group_name = var.parameter_group_name

  subnet_group_name  = var.create_subnet_group ? aws_elasticache_subnet_group.this[0].name : null
  security_group_ids = length(var.security_group_ids) > 0 ? var.security_group_ids : null

  # Encryption — disabled in lab (no KMS), enabled in prod.
  # Prod: at_rest_encryption_enabled = true, kms_key_id = var.kms_key_arn
  #       transit_encryption_enabled  = true
  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled

  # Multi-AZ failover — needs num_cache_clusters >= 2 and multiple subnets.
  automatic_failover_enabled = var.automatic_failover_enabled
  multi_az_enabled           = var.multi_az_enabled

  # Snapshots — 0 = disabled (lab). Prod: 7+ days for PITR within the window.
  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window          = var.snapshot_window
  maintenance_window       = var.maintenance_window

  apply_immediately = var.apply_immediately

  tags = merge(local.common_tags, {
    Name = local.name
  })
}

# ── Redis cluster (lab / Ministack) ────────────────────────────────────────────
# aws_elasticache_cluster is a single-node resource. It works reliably with
# Ministack and LocalStack. Use this for lab environments.
# Set use_replication_group = false (default) for lab.
resource "aws_elasticache_cluster" "this" {
  count = var.enabled && !var.use_replication_group ? 1 : 0

  cluster_id           = local.name
  engine               = "redis"
  node_type            = var.node_type
  num_cache_nodes      = 1
  engine_version       = var.engine_version
  port                 = 6379
  parameter_group_name = var.parameter_group_name

  subnet_group_name  = var.create_subnet_group ? aws_elasticache_subnet_group.this[0].name : null
  security_group_ids = length(var.security_group_ids) > 0 ? var.security_group_ids : null

  apply_immediately = var.apply_immediately

  tags = merge(local.common_tags, {
    Name = local.name
  })
}
