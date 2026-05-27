# ── Lambda execution role ──────────────────────────────────────────────────────
# Assumed by the Lambda SERVICE, not the function code.
# Grants: write logs to CloudWatch, pull from SQS, read secrets, access VPC.
# Separation: this role = infrastructure access. Function code = no extra perms
# unless explicitly granted via a separate task-like policy below.
resource "aws_iam_role" "lambda_execution" {
  name = "${var.project}-${var.environment}-lambda-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowLambdaAssume"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# ── Basic execution policy ─────────────────────────────────────────────────────
# Covers CloudWatch Logs + VPC ENI management.
# AWSLambdaVPCAccessExecutionRole includes VPC-specific perms (ec2:CreateNetworkInterface,
# ec2:DescribeNetworkInterfaces, ec2:DeleteNetworkInterface) needed for VPC attachment.
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ── Custom permissions for function code ───────────────────────────────────────
# SQS: receive + delete (event source mapping manages visibility, but the function
#      itself must delete messages after successful processing).
# S3: get object (s3_processor needs to download the object it's notified about).
# SSM: read parameters for runtime config injection.
# Secrets Manager: read DB credentials if function needs direct RDS access.
resource "aws_iam_policy" "lambda_app" {
  name        = "${var.project}-${var.environment}-lambda-app-policy"
  description = "App-level permissions for ${var.project}-${var.environment} Lambda functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      length(var.sqs_queue_arns) > 0 ? [{
        Sid    = "SQSConsume"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:ChangeMessageVisibility",
          "sqs:GetQueueAttributes",
        ]
        Resource = var.sqs_queue_arns
      }] : [],

      var.s3_bucket_arn != "" ? [{
        Sid      = "S3Read"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${var.s3_bucket_arn}/*"
      }] : [],

      length(var.ssm_parameter_arns) > 0 ? [{
        Sid      = "SSMReadConfig"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Resource = var.ssm_parameter_arns
      }] : [],

      length(var.secret_arns) > 0 ? [{
        Sid      = "SecretsManagerRead"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.secret_arns
      }] : [],
    )
  })

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_app" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_app.arn
}
