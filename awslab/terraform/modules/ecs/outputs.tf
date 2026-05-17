output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.this.id
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.this.name
}

output "task_definition_arn" {
  description = "Active task definition ARN (includes revision)"
  value       = aws_ecs_task_definition.this.arn
}

output "ecr_repository_url" {
  description = "ECR repository URL — use this as the base for docker push"
  value       = aws_ecr_repository.this.repository_url
}

output "ecr_repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.this.arn
}

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role (used by the ECS agent)"
  value       = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task role (used by the application)"
  value       = aws_iam_role.task.arn
}

output "log_group_name" {
  description = "CloudWatch log group name for container logs"
  value       = aws_cloudwatch_log_group.this.name
}

