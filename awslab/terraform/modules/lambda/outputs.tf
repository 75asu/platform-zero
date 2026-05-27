output "orders_analytics_arn" {
  description = "ARN of the orders-analytics Lambda function. Pass to Scheduler as the invocation target."
  value       = aws_lambda_function.orders_analytics.arn
}

output "orders_analytics_name" {
  description = "Name of the orders-analytics function."
  value       = aws_lambda_function.orders_analytics.function_name
}

output "s3_processor_arn" {
  description = "ARN of the s3-processor Lambda function."
  value       = aws_lambda_function.s3_processor.arn
}

output "s3_processor_name" {
  description = "Name of the s3-processor function."
  value       = aws_lambda_function.s3_processor.function_name
}

output "execution_role_arn" {
  description = "ARN of the shared Lambda execution role. Pass to Scheduler (needs lambda:InvokeFunction on this role)."
  value       = aws_iam_role.lambda_execution.arn
}

output "analytics_queue_arn" {
  description = "ARN of the analytics SQS queue. Pass to SNS module as a subscriber."
  value       = aws_sqs_queue.analytics.arn
}

output "analytics_queue_url" {
  description = "URL of the analytics SQS queue."
  value       = aws_sqs_queue.analytics.url
}

output "security_group_id" {
  description = "ID of the Lambda security group. Empty string when vpc_id is not set."
  value       = length(aws_security_group.lambda) > 0 ? aws_security_group.lambda[0].id : ""
}
