resource "aws_iam_role" "cross_account" {
  count = var.cross_account_trusted_account_id != "" ? 1 : 0

  name                 = "${var.project}-${var.environment}-cross-account"
  permissions_boundary = local.boundary_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountAssume"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.cross_account_trusted_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.cross_account_external_id
          }
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}
