variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project name — prefixed to the topic name"
  type        = string
  default     = "platform-zero"
}

variable "topic_name" {
  description = "Logical topic name — becomes {project}-{environment}-{topic_name}"
  type        = string
}

# ── Access control ─────────────────────────────────────────────────────────────

variable "publisher_arns" {
  description = <<-EOT
    IAM principal ARNs allowed to publish to this topic (sns:Publish).
    Typically: ECS task role ARN, Lambda execution role ARN, CI deploy role ARN.
    Empty list = no publisher policy statement (access via identity policies only).
  EOT
  type        = list(string)
  default     = []
}

variable "sqs_subscriber_arns" {
  description = <<-EOT
    ARNs of SQS queues that subscribe to this topic.
    One aws_sns_topic_subscription is created per ARN.
    The topic policy also grants sqs:SendMessage to these queues so SNS can deliver.
  EOT
  type        = list(string)
  default     = []
}

# ── Delivery ───────────────────────────────────────────────────────────────────

variable "raw_message_delivery" {
  description = <<-EOT
    When true: SNS delivers the raw message body without the SNS envelope.
    When false (default): SNS wraps the message with Type, MessageId, TopicArn, etc.
    Leave false when consumers need to distinguish SNS source or inspect metadata.
    Set true for simple pass-through where consumers only care about the payload.
  EOT
  type        = bool
  default     = false
}
