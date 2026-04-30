locals {
  boundary_arn = var.enable_permission_boundary ? aws_iam_policy.platform_boundary.arn : null
}
