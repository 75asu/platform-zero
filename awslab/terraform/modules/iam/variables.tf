variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project tag applied to all resources"
  type        = string
  default     = "platform-zero"
}

variable "aws_region" {
  description = "Region to lock IAM conditions to"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID — used in ARN conditions and trust policies"
  type        = string
  default     = "000000000000"
}

variable "github_org" {
  description = "GitHub organisation name (e.g. 75asu)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (e.g. platform-zero)"
  type        = string
}

variable "github_oidc_thumbprint" {
  description = "TLS thumbprint of GitHub's OIDC endpoint certificate"
  type        = string
  default     = "6938fd4d98bab03faadb97b34396831e3780aea1"
}

variable "enable_permission_boundary" {
  description = "Attach the platform permission boundary to all roles"
  type        = bool
  default     = true
}

variable "cross_account_trusted_account_id" {
  description = "AWS account ID allowed to assume the cross-account role. Empty string disables the role."
  type        = string
  default     = ""
}

variable "cross_account_external_id" {
  description = "ExternalId secret for cross-account assume-role (confused deputy protection)"
  type        = string
  sensitive   = true
  default     = ""
}
