resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# Layer 1: Versioning
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# Layer 2: Encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.encryption_algorithm
      kms_master_key_id = var.kms_master_key_id
    }
    bucket_key_enabled = var.encryption_algorithm == "aws:kms"
  }
}

# Layer 3: Block Public Access (all 4 settings)
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true

}

# Layer 4: Bucket policy
# Always enforces: deny HTTP, deny unencrypted uploads.
# When allowed_role_arns is set: also restricts read/write to those
# specific IAM roles — Principal:* is removed from data-access statements.
# This is the IAM-as-wrapper pattern: IAM module outputs role ARNs,
# this module consumes them to close the resource-policy side.
resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id

  depends_on = [aws_s3_bucket_public_access_block.this]

  policy = jsonencode({
    Version = "2012-10-17"
    # concat() with for-expression pattern: each ternary toggles between [1] and []
    # — same type in both branches — so Terraform's type checker is satisfied.
    # The for expression then maps to the actual statement object.
    Statement = concat(
      [
        {
          Sid       = "DenyHTTP"
          Effect    = "Deny"
          Principal = "*"
          Action    = "s3:*"
          Resource = [
            aws_s3_bucket.this.arn,
            "${aws_s3_bucket.this.arn}/*"
          ]
          Condition = {
            Bool = {
              "aws:SecureTransport" = "false"
            }
          }
        },
        {
          Sid       = "DenyUnencryptedUploads"
          Effect    = "Deny"
          Principal = "*"
          Action    = "s3:PutObject"
          Resource  = "${aws_s3_bucket.this.arn}/*"
          Condition = {
            "Null" = {
              "s3:x-amz-server-side-encryption" = "true"
            }
          }
        }
      ],
      [for _ in (length(var.allowed_role_arns) > 0 ? [1] : []) : {
        Sid    = "AllowScopedRoles"
        Effect = "Allow"
        Principal = {
          AWS = var.allowed_role_arns
        }
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
          "s3:ListBucket", "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.this.arn,
          "${aws_s3_bucket.this.arn}/*"
        ]
      }],
      [for _ in (length(var.allowed_role_arns) > 0 ? [1] : []) : {
        Sid    = "DenyAllOtherPrincipals"
        Effect = "Deny"
        Principal = "*"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.this.arn,
          "${aws_s3_bucket.this.arn}/*"
        ]
        Condition = {
          ArnNotLike = {
            "aws:PrincipalArn" = var.allowed_role_arns
          }
        }
      }],
    )
  })
}

# Layer 5: Lifecycle rules
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  # versioning must be enabled before lifecycle rules referencing noncurrent versions
  depends_on = [aws_s3_bucket_versioning.this]

  rule {
    id     = "main"
    status = "Enabled"

    filter {} # apply to all objects

    dynamic "transition" {
      for_each = var.lifecycle_transition_ia_days > 0 ? [1] : []
      content {
        days          = var.lifecycle_transition_ia_days
        storage_class = "STANDARD_IA"
      }
    }

    dynamic "transition" {
      for_each = var.lifecycle_transition_glacier_days > 0 ? [1] : []
      content {
        days          = var.lifecycle_transition_glacier_days
        storage_class = "GLACIER"
      }
    }

    dynamic "expiration" {
      for_each = var.lifecycle_expiration_days > 0 ? [1] : []
      content {
        days = var.lifecycle_expiration_days
      }
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }
}

# Layer 6: Server access logging (optional)
resource "aws_s3_bucket_logging" "this" {
  count = var.logging_target_bucket != null ? 1 : 0

  bucket        = aws_s3_bucket.this.id
  target_bucket = var.logging_target_bucket
  target_prefix = var.logging_target_prefix
}
