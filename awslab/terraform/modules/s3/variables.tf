variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project tag"
  type        = string
  default     = "platform-zero"
}

variable "versioning_enabled" {
  description = "Enable object versioning"
  type        = bool
  default     = true
}

variable "encryption_algorithm" {
  description = "Server-side encryption algorithm (AES256 or aws:kms)"
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "aws:kms"], var.encryption_algorithm)
    error_message = "encryption_algorithm must be AES256 or aws:kms"
  }
}

variable "kms_master_key_id" {
  description = "KMS key ID if encryption_algorithm is aws:kms. Leave null for SSE-S3."
  type        = string
  default     = null
}

variable "lifecycle_transition_ia_days" {
  description = "Days before transitioning current objects to STANDARD_IA. Set to 0 to disable."
  type        = number
  default     = 30
}

variable "lifecycle_transition_glacier_days" {
  description = "Days before transitioning current objects to GLACIER. Set to 0 to disable."
  type        = number
  default     = 90
}

variable "lifecycle_expiration_days" {
  description = "Days before expiring (deleting) current objects. Set to 0 to disable."
  type        = number
  default     = 365
}

variable "noncurrent_version_expiration_days" {
  description = "Days to keep non-current versions before deleting them"
  type        = number
  default     = 30
}

variable "logging_target_bucket" {
  description = "Bucket to receive server access logs. Leave null to disable logging."
  type        = string
  default     = null
}

variable "logging_target_prefix" {
  description = "Prefix for log objects in the logging target bucket"
  type        = string
  default     = "s3-access-logs/"
}

variable "allowed_role_arns" {
  description = "IAM role ARNs allowed to read/write this bucket. When non-empty, bucket policy restricts access to these roles only (plus the DenyHTTP/DenyUnencrypted statements). Empty list = bucket policy keeps Principal:* with condition-only restrictions."
  type        = list(string)
  default     = []
}
