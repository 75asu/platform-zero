locals {
  base_name = "${var.project}-${var.environment}-${var.queue_name}"

  # FIFO queues must end in .fifo — AWS enforces this at the API level.
  queue_name = var.fifo_queue ? "${local.base_name}.fifo" : local.base_name
  dlq_name   = var.fifo_queue ? "${local.base_name}-dlq.fifo" : "${local.base_name}-dlq"

  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# ── Dead letter queue ──────────────────────────────────────────────────────────
# Created first — main queue references its ARN in the redrive policy.
resource "aws_sqs_queue" "dlq" {
  name = local.dlq_name

  # Longer retention for the DLQ — messages here need manual inspection.
  message_retention_seconds = var.dlq_message_retention_seconds

  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null

  tags = merge(local.common_tags, {
    Name = local.dlq_name
    Role = "dead-letter-queue"
  })
}

# Allow the main queue to use this DLQ.
# redrivePermission = byQueue restricts to only the queues listed in sourceQueueArns.
resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.url

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.main.arn]
  })
}

# ── Main queue ─────────────────────────────────────────────────────────────────
resource "aws_sqs_queue" "main" {
  name = local.queue_name

  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  max_message_size           = var.max_message_size
  delay_seconds              = var.delay_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds

  # Wire to DLQ — after max_receive_count failed processing attempts,
  # SQS moves the message to the DLQ automatically.
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null

  tags = merge(local.common_tags, {
    Name = local.queue_name
    Role = "main-queue"
  })
}

# ── Queue resource policy ──────────────────────────────────────────────────────
# Only created when at least one set of ARNs is provided.
# If both lists are empty, access is controlled by IAM identity policies alone —
# valid for internal queues where producers and consumers share the same account.
resource "aws_sqs_queue_policy" "main" {
  count     = (length(var.allowed_sender_arns) + length(var.allowed_consumer_arns)) > 0 ? 1 : 0
  queue_url = aws_sqs_queue.main.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      length(var.allowed_sender_arns) > 0 ? [{
        Sid       = "AllowSenders"
        Effect    = "Allow"
        Principal = { AWS = var.allowed_sender_arns }
        Action    = ["sqs:SendMessage"]
        Resource  = aws_sqs_queue.main.arn
      }] : [],
      length(var.allowed_consumer_arns) > 0 ? [{
        Sid       = "AllowConsumers"
        Effect    = "Allow"
        Principal = { AWS = var.allowed_consumer_arns }
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:ChangeMessageVisibility",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.main.arn
      }] : [],
    )
  })
}
