resource "aws_iam_policy" "platform_boundary" {
  name        = "${var.project}-${var.environment}-platform-boundary"
  description = "Permission boundary — ceiling on all roles in ${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCoreServices"
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
          "s3:GetBucketLocation", "s3:ListBucket",
          "sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage",
          "sqs:GetQueueAttributes", "sqs:GetQueueUrl",
          "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents",
          "ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath",
          "secretsmanager:GetSecretValue",
          "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken",
          "sts:AssumeRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid    = "DenyLongLivedKeys"
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:CreateAccessKey",
          "iam:UpdateAccessKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}
