resource "aws_iam_role" "ci_deploy" {
  name                 = "${var.project}-${var.environment}-ci-deploy"
  permissions_boundary = local.boundary_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowGitHubOIDC"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
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

resource "aws_iam_policy" "ci_deploy" {
  name        = "${var.project}-${var.environment}-ci-deploy-policy"
  description = "CI deploy — Terraform apply for ${var.environment} only"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::platform-zero-tfstate",
          "arn:aws:s3:::platform-zero-tfstate/live/${var.environment}/*"
        ]
      },
      {
        Sid    = "DynamoDBStateLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem", "dynamodb:PutItem",
          "dynamodb:DeleteItem", "dynamodb:DescribeTable"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/platform-zero-tfstate-lock"
      },
      {
        Sid    = "DeployResources"
        Effect = "Allow"
        Action = [
          "s3:*", "sqs:*", "ecs:*", "ec2:Describe*",
          "iam:PassRole", "iam:GetRole", "iam:ListRolePolicies",
          "logs:*", "ecr:*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion"          = var.aws_region
            "aws:ResourceTag/Environment"  = var.environment
          }
        }
      },
      {
        Sid    = "DenyLongLivedKeyCreation"
        Effect = "Deny"
        Action = ["iam:CreateUser", "iam:CreateAccessKey"]
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

resource "aws_iam_role_policy_attachment" "ci_deploy" {
  role       = aws_iam_role.ci_deploy.name
  policy_arn = aws_iam_policy.ci_deploy.arn
}
