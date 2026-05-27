variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project name — prefixed to all resource names"
  type        = string
  default     = "platform-zero"
}

# ── Runtime ────────────────────────────────────────────────────────────────────

variable "runtime" {
  description = "Lambda runtime. Python 3.12 is the latest stable. Real AWS: pin to a specific runtime, not 'python3.x'."
  type        = string
  default     = "python3.12"
}

variable "function_timeout" {
  description = <<-EOT
    Maximum seconds a function can run before Lambda terminates it.
    Must be >= SQS visibility_timeout_seconds to prevent duplicate processing.
    analytics queue visibility_timeout = 300s, so timeout must be <= 300.
  EOT
  type        = number
  default     = 60
}

variable "memory_size" {
  description = "MB allocated to each function. Lambda also scales CPU proportionally to memory."
  type        = number
  default     = 256
}

variable "log_level" {
  description = "LOG_LEVEL env var injected into all functions. Used by Python logging module."
  type        = string
  default     = "INFO"
}

# ── VPC ────────────────────────────────────────────────────────────────────────

variable "vpc_id" {
  description = <<-EOT
    VPC ID for Lambda VPC attachment. Required for functions that access ElastiCache or RDS.
    Leave empty to run Lambda outside VPC (no private subnet access, but faster cold starts).
  EOT
  type        = string
  default     = ""
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for VPC-attached functions. Use private (not data) subnets for Lambda."
  type        = list(string)
  default     = []
}

# ── Event sources ──────────────────────────────────────────────────────────────

variable "sqs_batch_size" {
  description = <<-EOT
    Max messages per Lambda invocation from SQS. 1-10 for standard queues (SQS default max per receive is 10).
    Higher = fewer invocations = lower cost. Lower = faster per-message processing.
  EOT
  type        = number
  default     = 10
}

variable "sns_topic_arn" {
  description = "SNS topic ARN to subscribe the analytics SQS queue to. Leave empty to skip SNS subscription."
  type        = string
  default     = ""
}

# ── S3 trigger ─────────────────────────────────────────────────────────────────

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket that triggers s3_processor on object creation. Used in IAM and Lambda permission."
  type        = string
  default     = ""
}

variable "s3_bucket_id" {
  description = "ID (name) of the S3 bucket for the notification config. Must match s3_bucket_arn."
  type        = string
  default     = ""
}

variable "s3_filter_prefix" {
  description = "S3 key prefix filter. Only objects under this prefix trigger the function. Empty = all objects."
  type        = string
  default     = ""
}

variable "s3_filter_suffix" {
  description = "S3 key suffix filter. E.g. '.json' to only trigger on JSON uploads."
  type        = string
  default     = ""
}

# ── IAM inputs ─────────────────────────────────────────────────────────────────

variable "sqs_queue_arns" {
  description = "SQS queue ARNs the functions are allowed to consume from. Passed to the execution role policy."
  type        = list(string)
  default     = []
}

variable "ssm_parameter_arns" {
  description = "SSM parameter ARNs the functions can read (ssm:GetParameter). Pass all_parameter_arns from the SSM module."
  type        = list(string)
  default     = []
}

variable "secret_arns" {
  description = "Secrets Manager secret ARNs the functions can read. E.g. RDS DB credentials."
  type        = list(string)
  default     = []
}

# ── Environment variables ──────────────────────────────────────────────────────

variable "extra_env_vars" {
  description = "Additional env vars injected into all functions alongside ENVIRONMENT, PROJECT, LOG_LEVEL."
  type        = map(string)
  default     = {}
}
