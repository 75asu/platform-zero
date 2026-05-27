output "topic_arn" {
  description = "ARN of the SNS topic. Pass to producer IAM policies (sns:Publish) and consumer subscriptions."
  value       = aws_sns_topic.this.arn
}

output "topic_name" {
  description = "Full name of the SNS topic as created in AWS."
  value       = aws_sns_topic.this.name
}

output "subscription_arns" {
  description = "Map of SQS queue ARN → subscription ARN. Useful for debugging delivery failures."
  value       = { for k, s in aws_sns_topic_subscription.sqs : k => s.arn }
}
