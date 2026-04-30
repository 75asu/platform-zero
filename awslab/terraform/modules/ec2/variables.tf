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
  description = "Region for ARN construction and IAM conditions"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID for ARN construction"
  type        = string
  default     = "000000000000"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20
}

variable "permission_boundary_arn" {
  description = "ARN of the platform permission boundary from the iam module. Empty string skips it."
  type        = string
  default     = ""
}

variable "ami_id_override" {
  description = "Hardcode an AMI ID for Ministack. Empty string = use data source (real AWS behavior)."
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Subnet to place the instance in. Empty string = use first default VPC subnet."
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC for the security group. Empty string = use default VPC."
  type        = string
  default     = ""
}

variable "enable_imdsv2" {
  description = "Enforce IMDSv2 (required tokens). Set false if Ministack does not support metadata_options."
  type        = bool
  default     = true
}

variable "encrypt_root_volume" {
  description = "Encrypt the root EBS volume. Set false if Ministack does not support EBS encryption."
  type        = bool
  default     = true
}

variable "create_instance" {
  description = "Set false for Ministack — aws_instance is not fully supported. IAM resources still created."
  type        = bool
  default     = true
}
