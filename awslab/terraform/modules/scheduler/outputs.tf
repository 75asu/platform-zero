output "schedule_group_name" {
  description = "Name of the EventBridge Scheduler schedule group."
  value       = aws_scheduler_schedule_group.this.name
}

output "schedule_group_arn" {
  description = "ARN of the schedule group."
  value       = aws_scheduler_schedule_group.this.arn
}

output "schedule_arns" {
  description = "Map of schedule name → ARN for all created schedules."
  value       = { for k, s in aws_scheduler_schedule.schedules : k => s.arn }
}

output "scheduler_role_arn" {
  description = "ARN of the IAM role assumed by EventBridge Scheduler when invoking targets."
  value       = aws_iam_role.scheduler.arn
}
