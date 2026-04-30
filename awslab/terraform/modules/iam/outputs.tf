output "permission_boundary_arn" {
  description = "ARN of the platform permission boundary — attach to any new role in this environment"
  value       = aws_iam_policy.platform_boundary.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider — reuse for additional OIDC roles"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "ci_deploy_role_arn" {
  description = "ARN of the CI deploy role — set in GitHub Actions as the role to assume"
  value       = aws_iam_role.ci_deploy.arn
}

output "cross_account_role_arn" {
  description = "ARN of the cross-account role — empty string if not enabled"
  value       = length(aws_iam_role.cross_account) > 0 ? aws_iam_role.cross_account[0].arn : ""
}
