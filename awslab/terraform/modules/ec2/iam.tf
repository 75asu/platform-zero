resource "aws_iam_role" "instance" {
  name                 = "${var.project}-${var.environment}-ec2-instance"
  permissions_boundary = var.permission_boundary_arn != "" ? var.permission_boundary_arn : null

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowEC2Assume"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_policy" "instance" {
  name        = "${var.project}-${var.environment}-ec2-instance-policy"
  description = "EC2 instance — SSM session access, CloudWatch logs/metrics, SSM parameter read"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # SSM Session Manager replaces SSH entirely.
        # These actions allow the SSM agent on the instance to open a session
        # back to the SSM service — no inbound port needed.
        Sid    = "SSMSessionManager"
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "ec2messages:GetMessages",
          "ec2messages:AcknowledgeMessage",
          "ec2messages:SendReply",
          "ec2messages:GetEndpoint"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/ec2/${var.project}-${var.environment}:*"
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = ["cloudwatch:PutMetricData"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = [
              "${var.project}/${var.environment}/EC2",
              "CWAgent"
            ]
          }
        }
      },
      {
        Sid    = "SSMParameterRead"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.project}/${var.environment}/*"
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "instance" {
  role       = aws_iam_role.instance.name
  policy_arn = aws_iam_policy.instance.arn
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.project}-${var.environment}-ec2-instance-profile"
  role = aws_iam_role.instance.name
}
