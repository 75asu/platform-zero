output "string_parameter_arns" {
  description = "Map of key → ARN for all String parameters. Use in IAM policies granting ssm:GetParameter."
  value       = { for k, p in aws_ssm_parameter.string : k => p.arn }
}

output "secure_parameter_arns" {
  description = "Map of key → ARN for all SecureString parameters. Use in ECS task execution role IAM policies."
  value       = { for k, p in aws_ssm_parameter.secure : k => p.arn }
}

output "string_parameter_names" {
  description = "Map of key → full SSM parameter name (path). Pass into ECS task definition `environment` blocks."
  value       = { for k, p in aws_ssm_parameter.string : k => p.name }
}

output "secure_parameter_names" {
  description = "Map of key → full SSM parameter name (path). Pass into ECS task definition `secrets` blocks."
  value       = { for k, p in aws_ssm_parameter.secure : k => p.name }
}

output "all_parameter_arns" {
  description = "Combined list of all parameter ARNs (String + SecureString). Convenience for IAM wildcard grants."
  value = concat(
    [for p in aws_ssm_parameter.string : p.arn],
    [for p in aws_ssm_parameter.secure : p.arn],
  )
}
