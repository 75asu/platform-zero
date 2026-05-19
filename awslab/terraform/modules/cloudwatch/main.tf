locals {
  name = "${var.project}-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# ── ECS CPU alarm ──────────────────────────────────────────────────────────────
# Pages when ECS service is CPU-saturated.
# At 80% CPU, tasks start queueing work — auto-scaling should kick in before this.
# If alarm fires and tasks aren't scaling, check appautoscaling policy or task limits.
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${local.name}-ecs-cpu-high"
  alarm_description   = "ECS CPU above ${var.ecs_cpu_threshold_pct}% for ${var.alarm_period}s"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.evaluation_periods
  threshold           = var.ecs_cpu_threshold_pct

  metric_name = "CPUUtilization"
  namespace   = "AWS/ECS"
  period      = var.alarm_period
  statistic   = "Average"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions

  tags = merge(local.common_tags, {
    Name = "${local.name}-ecs-cpu-high"
  })
}

# ── ECS Memory alarm ───────────────────────────────────────────────────────────
# Memory in ECS is a hard limit — at 100% the task is OOM-killed and restarted.
# 80% threshold gives you time to react before restarts start.
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${local.name}-ecs-memory-high"
  alarm_description   = "ECS Memory above ${var.ecs_memory_threshold_pct}% for ${var.alarm_period}s"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.evaluation_periods
  threshold           = var.ecs_memory_threshold_pct

  metric_name = "MemoryUtilization"
  namespace   = "AWS/ECS"
  period      = var.alarm_period
  statistic   = "Average"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions

  tags = merge(local.common_tags, {
    Name = "${local.name}-ecs-memory-high"
  })
}

# ── SQS DLQ depth alarm ────────────────────────────────────────────────────────
# Any message in the DLQ means a consumer failed max_receive_count times.
# This is the most important SQS alarm — silent DLQ growth = silent data loss.
# Threshold = 1: alert immediately on first failed message.
resource "aws_cloudwatch_metric_alarm" "sqs_dlq_depth" {
  alarm_name          = "${local.name}-sqs-dlq-depth"
  alarm_description   = "Messages in DLQ — consumer is failing, messages not being processed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 1

  metric_name = "ApproximateNumberOfMessagesVisible"
  namespace   = "AWS/SQS"
  period      = var.alarm_period
  statistic   = "Sum"

  dimensions = {
    QueueName = var.sqs_dlq_name
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions

  tags = merge(local.common_tags, {
    Name = "${local.name}-sqs-dlq-depth"
  })
}

# ── RDS connections alarm ──────────────────────────────────────────────────────
# RDS has a hard max_connections limit based on instance class.
# At 80% usage, new connections are refused — app returns "too many clients" errors.
# With Fargate (tasks spawn/die constantly) this can spike fast without RDS Proxy.
resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  alarm_name          = "${local.name}-rds-connections-high"
  alarm_description   = "RDS connections above ${var.rds_connection_threshold} — approaching instance limit"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.evaluation_periods
  threshold           = var.rds_connection_threshold

  metric_name = "DatabaseConnections"
  namespace   = "AWS/RDS"
  period      = var.alarm_period
  statistic   = "Average"

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions

  tags = merge(local.common_tags, {
    Name = "${local.name}-rds-connections-high"
  })
}

# ── ALB 5xx error rate alarm ───────────────────────────────────────────────────
# HTTPCode_Target_5XX_Count: errors from your app (not ALB itself).
# Spike here = app is broken, not just overloaded.
# Expression alarm: rate = 5xx / total requests × 100.
resource "aws_cloudwatch_metric_alarm" "alb_5xx_high" {
  alarm_name          = "${local.name}-alb-5xx-high"
  alarm_description   = "ALB 5xx error rate above ${var.alb_5xx_threshold_pct}%"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.evaluation_periods
  threshold           = var.alb_5xx_threshold_pct

  metric_name = "HTTPCode_Target_5XX_Count"
  namespace   = "AWS/ApplicationELB"
  period      = var.alarm_period
  statistic   = "Sum"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions

  tags = merge(local.common_tags, {
    Name = "${local.name}-alb-5xx-high"
  })
}
