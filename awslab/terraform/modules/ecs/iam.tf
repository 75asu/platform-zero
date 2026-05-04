# ── Task execution role ────────────────────────────────────────────────────────
# Used by the ECS AGENT, not the application.
# Allows ECS to: pull the image from ECR, write logs to CloudWatch,
# and fetch secrets for environment variable injection.
# This role is always needed — without it ECS can't start the container.
resource "aws_iam_role" "task_execution" {
  name = "${var.project}-${var.environment}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowECSAssume"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# AWS-managed policy covering all ECS agent needs.
# Grants: ecr:GetAuthorizationToken, ecr:BatchGetImage, logs:CreateLogStream,
# logs:PutLogEvents, secretsmanager:GetSecretValue (for secrets injection).
resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ── Task role ──────────────────────────────────────────────────────────────────
# Used by the APPLICATION PROCESS running inside the container.
# This is what the app uses when it calls AWS APIs (SQS, Secrets Manager, S3).
# Separation from execution role = least privilege:
# ECS agent can't use app permissions and vice versa.
resource "aws_iam_role" "task" {
  name = "${var.project}-${var.environment}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowECSAssume"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# Custom policy for app-level AWS access.
# Statements are conditional — only added when ARNs are wired in.
# Pattern: SQS module outputs queue_arn → live config → this policy.
#          RDS module outputs secret_arn  → live config → this policy.
resource "aws_iam_policy" "task" {
  name        = "${var.project}-${var.environment}-ecs-task-policy"
  description = "App-level AWS access for ${var.project}-${var.environment} ECS tasks"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      length(var.sqs_queue_arns) > 0 ? [{
        Sid    = "SQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:ChangeMessageVisibility",
          "sqs:GetQueueAttributes"
        ]
        Resource = var.sqs_queue_arns
      }] : [],
      length(var.rds_secret_arns) > 0 ? [{
        Sid      = "SecretsManagerAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.rds_secret_arns
      }] : [],
      # Baseline: allow the task to describe its own cluster/service metadata.
      [{
        Sid    = "ECSReadSelf"
        Effect = "Allow"
        Action = [
          "ecs:DescribeTasks",
          "ecs:DescribeTaskDefinition"
        ]
        Resource = "*"
      }]
    )
  })

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "task" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.task.arn
}
