locals {
  identifier = "${var.project}-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# ── Parameter group ────────────────────────────────────────────────────────────
# Custom parameter group so config is tracked in Terraform, not the AWS console.
# Default parameter group is shared and cannot be modified.
resource "aws_db_parameter_group" "this" {
  name        = "${local.identifier}-${var.parameter_group_family}"
  family      = var.parameter_group_family
  description = "Custom parameters for ${local.identifier}"

  parameter {
    name         = "max_connections"
    value        = var.max_connections
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "log_min_duration_statement"
    value        = var.log_min_duration_statement
    apply_method = "immediate"
  }

  # Log all DDL (CREATE, DROP, ALTER) regardless of duration — always useful for auditing.
  parameter {
    name         = "log_statement"
    value        = "ddl"
    apply_method = "immediate"
  }

  tags = merge(local.common_tags, {
    Name = "${local.identifier}-${var.parameter_group_family}"
  })
}

# ── Subnet group ───────────────────────────────────────────────────────────────
# Only created when running in real AWS with a VPC.
# Ministack has no VPC support — set create_subnet_group = false in live configs.
resource "aws_db_subnet_group" "this" {
  count = var.create_subnet_group ? 1 : 0

  name        = local.identifier
  subnet_ids  = var.subnet_ids
  description = "DB subnet group for ${local.identifier}"

  tags = merge(local.common_tags, {
    Name = local.identifier
  })
}

# ── RDS instance ───────────────────────────────────────────────────────────────
resource "aws_db_instance" "this" {
  identifier = local.identifier

  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = var.storage_type
  storage_encrypted = var.storage_encrypted

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  parameter_group_name = aws_db_parameter_group.this.name
  db_subnet_group_name = var.create_subnet_group ? aws_db_subnet_group.this[0].name : null

  vpc_security_group_ids = length(var.vpc_security_group_ids) > 0 ? var.vpc_security_group_ids : null

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  apply_immediately       = var.apply_immediately

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot

  # Disable features Ministack doesn't support.
  # In real AWS: set performance_insights_enabled = true, monitoring_interval = 60
  performance_insights_enabled = false
  monitoring_interval          = 0

  tags = merge(local.common_tags, {
    Name = local.identifier
  })
}

# ── Secrets Manager ────────────────────────────────────────────────────────────
# Store DB credentials in Secrets Manager so apps never hardcode connection strings.
# App pattern: call GetSecretValue at startup, parse JSON, build connection string.
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.project}/${var.environment}/rds/credentials"
  description = "DB credentials for ${local.identifier} — username, password, host, port, dbname"

  # 0 = no recovery window (immediate delete on destroy). Set 7-30 in prod.
  recovery_window_in_days = 0

  tags = merge(local.common_tags, {
    Name = "${var.project}/${var.environment}/rds/credentials"
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  # Standard RDS secret format — compatible with RDS Proxy and most SDK integrations.
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.db_name
    engine   = var.engine
  })
}
