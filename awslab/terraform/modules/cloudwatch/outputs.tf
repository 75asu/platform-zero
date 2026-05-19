output "ecs_cpu_alarm_arn" {
  description = "ARN of the ECS CPU high alarm"
  value       = aws_cloudwatch_metric_alarm.ecs_cpu_high.arn
}

output "ecs_memory_alarm_arn" {
  description = "ARN of the ECS Memory high alarm"
  value       = aws_cloudwatch_metric_alarm.ecs_memory_high.arn
}

output "sqs_dlq_alarm_arn" {
  description = "ARN of the SQS DLQ depth alarm"
  value       = aws_cloudwatch_metric_alarm.sqs_dlq_depth.arn
}

output "rds_connections_alarm_arn" {
  description = "ARN of the RDS connections high alarm"
  value       = aws_cloudwatch_metric_alarm.rds_connections_high.arn
}

output "alb_5xx_alarm_arn" {
  description = "ARN of the ALB 5xx high alarm"
  value       = aws_cloudwatch_metric_alarm.alb_5xx_high.arn
}
