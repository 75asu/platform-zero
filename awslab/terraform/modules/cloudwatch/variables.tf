variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project tag applied to all resources"
  type        = string
  default     = "platform-zero"
}

# ── Target resource identifiers ────────────────────────────────────────────────

variable "ecs_cluster_name" {
  description = "ECS cluster name — used as CloudWatch dimension. Wire from ecs module output."
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name — used as CloudWatch dimension. Wire from ecs module output."
  type        = string
}

variable "sqs_dlq_name" {
  description = <<-EOT
    SQS dead-letter queue name — used as CloudWatch dimension.
    Wire from sqs module output: dependency.sqs.outputs.dlq_name
  EOT
  type = string
}

variable "rds_instance_id" {
  description = "RDS DB instance identifier — used as CloudWatch dimension. Wire from rds module output."
  type        = string
}

variable "alb_arn_suffix" {
  description = <<-EOT
    ALB ARN suffix for CloudWatch dimensions.
    Format: app/{alb-name}/{hex-id}
    Wire from alb module output: dependency.alb.outputs.arn_suffix
  EOT
  type = string
}

# ── Alarm thresholds ───────────────────────────────────────────────────────────

variable "ecs_cpu_threshold_pct" {
  description = "ECS CPU utilization % that triggers the alarm. 80 is a safe prod threshold."
  type        = number
  default     = 80
}

variable "ecs_memory_threshold_pct" {
  description = "ECS Memory utilization % that triggers the alarm. OOM kill happens at 100%."
  type        = number
  default     = 80
}

variable "rds_connection_threshold" {
  description = <<-EOT
    Number of DB connections that triggers the alarm.
    Set to ~80% of your instance's max_connections.
    db.t3.micro max_connections = 66, so threshold = 53.
    db.r6g.large max_connections = 4000+, threshold = 3200.
  EOT
  type    = number
  default = 50
}

variable "alb_5xx_threshold_pct" {
  description = "ALB 5xx count per period that triggers the alarm. Tune based on traffic volume."
  type        = number
  default     = 10
}

# ── Alarm behaviour ────────────────────────────────────────────────────────────

variable "alarm_period" {
  description = "CloudWatch evaluation period in seconds. 60 = per-minute resolution."
  type        = number
  default     = 60
}

variable "evaluation_periods" {
  description = <<-EOT
    Number of periods that must breach threshold before alarm fires.
    1 = alert on first breach (noisy but fast).
    3 = sustained breach required (reduces false positives for spiky traffic).
  EOT
  type    = number
  default = 2
}

variable "alarm_actions" {
  description = <<-EOT
    SNS topic ARNs to notify when alarm state changes.
    Empty list = alarm state changes are recorded but no notification is sent.
    Wire in an SNS topic ARN for PagerDuty/Slack in prod.
  EOT
  type    = list(string)
  default = []
}
