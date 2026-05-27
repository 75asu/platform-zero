output "topic_name" {
  description = "Short name of the main topic"
  value       = google_pubsub_topic.this.name
}

output "topic_id" {
  description = "Full topic resource ID (projects/{project}/topics/{name})"
  value       = google_pubsub_topic.this.id
}

output "dlq_topic_name" {
  description = "Short name of the dead letter topic"
  value       = google_pubsub_topic.dlq.name
}

output "dlq_topic_id" {
  description = "Full dead letter topic resource ID"
  value       = google_pubsub_topic.dlq.id
}

output "pull_subscription_name" {
  description = "Short name of the pull subscription"
  value       = google_pubsub_subscription.pull.name
}

output "pull_subscription_id" {
  description = "Full pull subscription resource ID"
  value       = google_pubsub_subscription.pull.id
}
