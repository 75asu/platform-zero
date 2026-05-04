output "queue_url" {
  description = "URL of the main queue — used by producers and consumers in SDK calls"
  value       = aws_sqs_queue.main.url
}

output "queue_arn" {
  description = "ARN of the main queue — used in IAM policies granting access to this queue"
  value       = aws_sqs_queue.main.arn
}

output "queue_name" {
  description = "Full name of the main queue as created in AWS"
  value       = aws_sqs_queue.main.name
}

output "dlq_url" {
  description = "URL of the dead letter queue"
  value       = aws_sqs_queue.dlq.url
}

output "dlq_arn" {
  description = "ARN of the dead letter queue"
  value       = aws_sqs_queue.dlq.arn
}

output "dlq_name" {
  description = "Full name of the dead letter queue as created in AWS"
  value       = aws_sqs_queue.dlq.name
}
