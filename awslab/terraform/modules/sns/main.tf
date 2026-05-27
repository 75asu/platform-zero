locals {
  name = "${var.project}-${var.environment}-${var.topic_name}"

  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# ── SNS topic ──────────────────────────────────────────────────────────────────
# Fan-out hub: one publish call here delivers to all subscribed SQS queues.
# Decouples producers (ECS service) from consumers (SQS workers, Lambda).
# Adding a new consumer = add a subscription. Producer code never changes.
resource "aws_sns_topic" "this" {
  name = local.name

  tags = merge(local.common_tags, {
    Name = local.name
  })
}

# ── Topic policy ───────────────────────────────────────────────────────────────
# Controls which IAM principals can publish and which SQS queues can receive.
# SQS subscriptions need sqs:SendMessage granted to the SNS service principal
# — without this, SNS fan-out silently fails (message published, never delivered).
resource "aws_sns_topic_policy" "this" {
  arn = aws_sns_topic.this.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Publishers: IAM principals (ECS task role, Lambda, CI) allowed to publish.
      length(var.publisher_arns) > 0 ? [{
        Sid       = "AllowPublishers"
        Effect    = "Allow"
        Principal = { AWS = var.publisher_arns }
        Action    = ["sns:Publish"]
        Resource  = aws_sns_topic.this.arn
      }] : [],

      # SQS delivery: SNS service principal must be allowed to write to each queue.
      # One statement per queue ARN — explicit resource scoping, not wildcard.
      length(var.sqs_subscriber_arns) > 0 ? [{
        Sid       = "AllowSQSDelivery"
        Effect    = "Allow"
        Principal = { Service = "sns.amazonaws.com" }
        Action    = ["sqs:SendMessage"]
        Resource  = var.sqs_subscriber_arns
        Condition = {
          ArnEquals = { "aws:SourceArn" = aws_sns_topic.this.arn }
        }
      }] : [],
    )
  })
}

# ── SQS subscriptions ──────────────────────────────────────────────────────────
# One subscription per queue ARN. SNS delivers a copy of each published message
# to every subscribed queue — this is the fan-out.
# raw_message_delivery = false (default): SNS wraps the message in its envelope
# (Type, MessageId, TopicArn, Timestamp, Signature, Message, MessageAttributes).
# Consumers must unwrap: json.loads(record["body"])["Message"].
resource "aws_sns_topic_subscription" "sqs" {
  for_each = toset(var.sqs_subscriber_arns)

  topic_arn = aws_sns_topic.this.arn
  protocol  = "sqs"
  endpoint  = each.value

  # raw_message_delivery skips the envelope — use when the consumer only needs
  # the message body. Leave false when consumers need SNS metadata.
  raw_message_delivery = var.raw_message_delivery
}
