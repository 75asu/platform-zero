locals {
  name = "${var.project}-${var.environment}-${var.topic_name}"
}

# ── Topics ─────────────────────────────────────────────────────────────────────

resource "google_pubsub_topic" "this" {
  name    = local.name
  project = var.project_id

  message_retention_duration = var.message_retention_duration
}

# Dead letter topic — receives messages that exceed max_delivery_attempts.
resource "google_pubsub_topic" "dlq" {
  name    = "${local.name}-dlq"
  project = var.project_id
}

# ── Subscriptions ──────────────────────────────────────────────────────────────

# Pull subscription — consumer polls on its own schedule.
# Pub/Sub also supports push subscriptions (Pub/Sub calls your HTTP endpoint).
resource "google_pubsub_subscription" "pull" {
  name    = "${local.name}-pull"
  project = var.project_id
  topic   = google_pubsub_topic.this.name

  # How long the consumer has to ack before Pub/Sub re-delivers. Match to
  # your maximum expected processing time per message.
  ack_deadline_seconds = var.ack_deadline_seconds

  # How long undelivered messages are retained in the subscription.
  message_retention_duration = var.message_retention_duration

  # After max_delivery_attempts failures, Pub/Sub routes the message to the DLQ.
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq.id
    max_delivery_attempts = var.max_delivery_attempts
  }

  retry_policy {
    minimum_backoff = var.retry_minimum_backoff
    maximum_backoff = var.retry_maximum_backoff
  }
}

# DLQ subscription — so dead-lettered messages don't accumulate indefinitely.
# Pull from this to inspect and replay failed messages.
resource "google_pubsub_subscription" "dlq_pull" {
  name    = "${local.name}-dlq-pull"
  project = var.project_id
  topic   = google_pubsub_topic.dlq.name

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s" # 7 days
}

# ── IAM ────────────────────────────────────────────────────────────────────────
# MiniSky's Pub/Sub shim does not implement topic or subscription IAM policies
# (returns 501 UNIMPLEMENTED). Omitted here.
# In real GCP: add google_pubsub_topic_iam_member for publisher SA and
# google_pubsub_subscription_iam_member for subscriber SA.
