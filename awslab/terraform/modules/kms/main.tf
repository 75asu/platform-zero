locals {
  alias_name = "alias/${var.project}/${var.environment}/${var.key_alias}"

  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# ── KMS Customer Managed Key ────────────────────────────────────────────────────
# CMK gives you control: audit every use via CloudTrail, rotate on your schedule,
# revoke access instantly by disabling the key.
# AWS-managed keys (aws/rds, aws/s3) cannot be audited per-call or revoked by you.
resource "aws_kms_key" "this" {
  description             = "${var.project}/${var.environment} — ${var.key_alias}"
  deletion_window_in_days = var.deletion_window_in_days

  # Automatic annual rotation — AWS replaces the backing key material.
  # Old key versions are kept to decrypt data encrypted with them.
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Root account always retains full access.
        # Without this, you can lock yourself out of the key permanently.
        Sid    = "RootFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        # Services that encrypt data at rest (RDS, ECS EBS volumes, ElastiCache).
        Sid    = "ServiceEncryptDecrypt"
        Effect = "Allow"
        Principal = {
          Service = var.allowed_services
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = local.alias_name
  })
}

# ── Alias ──────────────────────────────────────────────────────────────────────
# Human-readable name for the key. Terraform and the console both use the alias.
# The underlying key ID never changes even if you rename the alias.
resource "aws_kms_alias" "this" {
  name          = local.alias_name
  target_key_id = aws_kms_key.this.key_id
}
