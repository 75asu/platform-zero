variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project name — used as the SSM path prefix: /{project}/{environment}/{key}"
  type        = string
  default     = "platform-zero"
}

# ── Parameter maps ─────────────────────────────────────────────────────────────

variable "string_parameters" {
  description = <<-EOT
    Non-sensitive runtime config. Each key becomes the SSM parameter path suffix:
    key "config/log-level" → parameter "/{project}/{env}/config/log-level".
    Value is stored and returned as plaintext.
  EOT
  type        = map(string)
  default     = {}
}

variable "secure_parameters" {
  description = <<-EOT
    Sensitive config stored as SecureString (KMS-encrypted at rest).
    Same path pattern as string_parameters.
    ECS reads these via the `secrets` block — decrypted and injected as env vars.
    Task execution role must have ssm:GetParameters on these ARNs.
  EOT
  type        = map(string)
  default     = {}
  sensitive   = true
}

# ── Encryption ─────────────────────────────────────────────────────────────────

variable "kms_key_id" {
  description = <<-EOT
    KMS key ID or ARN for SecureString encryption.
    Leave empty to use the AWS-managed default key (alias/aws/ssm).
    Real AWS: pass the CMK ARN from the KMS module for customer-managed encryption.
  EOT
  type        = string
  default     = ""
}
