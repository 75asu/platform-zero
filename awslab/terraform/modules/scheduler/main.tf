locals {
  name = "${var.project}-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# ── Schedule group ─────────────────────────────────────────────────────────────
# Logical container for schedules. Deleting the group deletes all schedules in it.
# One group per environment — keeps dev and staging schedules isolated.
resource "aws_scheduler_schedule_group" "this" {
  name = local.name

  tags = merge(local.common_tags, {
    Name = local.name
  })
}

# ── Scheduler execution role ───────────────────────────────────────────────────
# EventBridge Scheduler assumes this role when invoking targets.
# The role must have lambda:InvokeFunction on every target function.
resource "aws_iam_role" "scheduler" {
  name = "${local.name}-scheduler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowSchedulerAssume"
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name}-scheduler"
  })
}

resource "aws_iam_role_policy" "scheduler_invoke" {
  name = "${local.name}-scheduler-invoke"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "InvokeLambdaTargets"
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = var.lambda_target_arns
    }]
  })
}

# ── Schedules ──────────────────────────────────────────────────────────────────
# flexible_time_window = OFF: invoke exactly at the scheduled time.
# Cron syntax: cron(minutes hours day-of-month month day-of-week year)
# Rate syntax: rate(value unit) — simpler for fixed intervals.
resource "aws_scheduler_schedule" "schedules" {
  for_each = var.schedules

  name       = "${local.name}-${each.key}"
  group_name = aws_scheduler_schedule_group.this.name

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = each.value.expression
  schedule_expression_timezone = var.timezone

  target {
    arn      = each.value.lambda_arn
    role_arn = aws_iam_role.scheduler.arn

    # Optional payload passed to the Lambda function.
    input = jsonencode(merge(
      { source = "scheduler", schedule = each.key },
      lookup(each.value, "payload", {}),
    ))

    retry_policy {
      maximum_retry_attempts       = var.max_retry_attempts
      maximum_event_age_in_seconds = var.max_event_age_seconds
    }
  }
}
