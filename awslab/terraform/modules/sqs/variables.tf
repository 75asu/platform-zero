variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project tag applied to all resources"
  type        = string
  default     = "platform-zero"
}

variable "queue_name" {
  description = "Logical queue name — becomes {project}-{environment}-{queue_name}[-dlq][.fifo]"
  type        = string
}

# ── Queue behaviour ────────────────────────────────────────────────────────────

variable "visibility_timeout_seconds" {
  description = <<-EOT
    How long a message is locked to one consumer after being received.
    Consumer must delete it within this window or it becomes visible again.
    Set >= max expected processing time. Default: 30s.
  EOT
  type        = number
  default     = 30
}

variable "message_retention_seconds" {
  description = "How long unprocessed messages stay in the queue. Default: 4 days."
  type        = number
  default     = 345600 # 4 days
}

variable "max_message_size" {
  description = "Maximum message body size in bytes. Default: 256 KB (SQS max)."
  type        = number
  default     = 262144
}

variable "delay_seconds" {
  description = "Seconds a new message is invisible to consumers after publish. Default: 0."
  type        = number
  default     = 0
}

variable "receive_wait_time_seconds" {
  description = <<-EOT
    Long-polling wait time. 0 = short polling (burns API calls + cost).
    1-20 = long polling (waits up to N seconds for a message before returning empty).
    Default: 20 (max long-poll — recommended for all standard queues).
  EOT
  type        = number
  default     = 20
}

# ── Dead letter queue ──────────────────────────────────────────────────────────

variable "max_receive_count" {
  description = <<-EOT
    Max times a message can be received before moving to the DLQ.
    After this many failed processing attempts the message is quarantined.
    Default: 3.
  EOT
  type        = number
  default     = 3
}

variable "dlq_message_retention_seconds" {
  description = "How long failed messages stay in the DLQ for inspection. Default: 14 days."
  type        = number
  default     = 1209600 # 14 days
}

# ── FIFO ───────────────────────────────────────────────────────────────────────

variable "fifo_queue" {
  description = <<-EOT
    Create a FIFO queue instead of standard.
    FIFO: exactly-once processing, ordered per message group, lower throughput (3000/s vs 120000/s).
    Standard: at-least-once, best-effort ordering, unlimited throughput.
  EOT
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "Auto-deduplicate by message body hash. Only valid when fifo_queue = true."
  type        = bool
  default     = false
}

# ── Access control ─────────────────────────────────────────────────────────────

variable "allowed_sender_arns" {
  description = <<-EOT
    IAM principal ARNs allowed to publish (sqs:SendMessage).
    Empty list = no queue resource policy — access controlled by IAM identity policies only.
  EOT
  type        = list(string)
  default     = []
}

variable "allowed_consumer_arns" {
  description = <<-EOT
    IAM principal ARNs allowed to consume (sqs:ReceiveMessage, DeleteMessage,
    ChangeMessageVisibility, GetQueueAttributes).
    Empty list = no queue resource policy — access controlled by IAM identity policies only.
  EOT
  type        = list(string)
  default     = []
}
