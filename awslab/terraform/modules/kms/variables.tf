variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project tag applied to all resources"
  type        = string
  default     = "platform-zero"
}

variable "aws_account_id" {
  description = "AWS account ID — used in root principal ARN in key policy"
  type        = string
  default     = "000000000000"
}

variable "key_alias" {
  description = "Short name for the key alias. Full alias becomes alias/{project}/{environment}/{key_alias}."
  type        = string
  default     = "main"
}

variable "deletion_window_in_days" {
  description = <<-EOT
    Days before the key is permanently deleted after destroy.
    AWS minimum is 7, maximum 30. Set 30 in prod to give time to recover from accidents.
    In lab: 7 is fine — speeds up teardown cycles.
  EOT
  type    = number
  default = 7
}

variable "allowed_services" {
  description = <<-EOT
    AWS service principals allowed to use this key for encryption at rest.
    Common values: rds.amazonaws.com, elasticache.amazonaws.com, ecs.amazonaws.com.
    Services call GenerateDataKey/Decrypt on your behalf when reading/writing encrypted data.
  EOT
  type    = list(string)
  default = ["rds.amazonaws.com", "elasticache.amazonaws.com"]
}
