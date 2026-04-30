output "instance_id" {
  description = "EC2 instance ID — empty string if create_instance is false"
  value       = length(aws_instance.this) > 0 ? aws_instance.this[0].id : ""
}

output "instance_arn" {
  description = "EC2 instance ARN — empty string if create_instance is false"
  value       = length(aws_instance.this) > 0 ? aws_instance.this[0].arn : ""
}

output "security_group_id" {
  description = "Instance security group ID — empty string if create_instance is false"
  value       = length(aws_security_group.instance) > 0 ? aws_security_group.instance[0].id : ""
}

output "instance_role_arn" {
  description = "ARN of the EC2 instance IAM role"
  value       = aws_iam_role.instance.arn
}

output "instance_profile_name" {
  description = "Instance profile name — pass to aws_instance.iam_instance_profile"
  value       = aws_iam_instance_profile.instance.name
}
