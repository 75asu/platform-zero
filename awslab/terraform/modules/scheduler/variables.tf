variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project name — prefixed to the schedule group and schedule names"
  type        = string
  default     = "platform-zero"
}

# ── Schedule targets ───────────────────────────────────────────────────────────

variable "lambda_target_arns" {
  description = <<-EOT
    ARNs of Lambda functions this scheduler is allowed to invoke.
    Used in the IAM role policy — must include every function ARN referenced in `schedules`.
  EOT
  type        = list(string)
  default     = []
}

variable "schedules" {
  description = <<-EOT
    Map of schedule name → config. Each entry creates one aws_scheduler_schedule.
    Keys:
      expression  - cron() or rate() expression
      lambda_arn  - ARN of the Lambda function to invoke
      payload     - (optional) extra fields merged into the Lambda input JSON
    Example:
      {
        nightly-cleanup = {
          expression = "cron(0 2 * * ? *)"
          lambda_arn = "arn:aws:lambda:..."
        }
        hourly-metrics = {
          expression = "rate(1 hour)"
          lambda_arn = "arn:aws:lambda:..."
          payload    = { mode = "aggregate" }
        }
      }
  EOT
  type = map(object({
    expression = string
    lambda_arn = string
    payload    = optional(map(string), {})
  }))
  default = {}
}

# ── Behaviour ──────────────────────────────────────────────────────────────────

variable "timezone" {
  description = "IANA timezone for cron expressions. Rate expressions are always UTC."
  type        = string
  default     = "UTC"
}

variable "max_retry_attempts" {
  description = "Max Lambda invocation retries on failure before EventBridge gives up. 0 = no retry."
  type        = number
  default     = 2
}

variable "max_event_age_seconds" {
  description = "Max age of an event before EventBridge drops it instead of retrying. Min: 60."
  type        = number
  default     = 3600 # 1 hour
}
