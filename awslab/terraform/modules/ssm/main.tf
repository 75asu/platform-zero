locals {
  name = "${var.project}-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# ── String parameters ──────────────────────────────────────────────────────────
# Non-sensitive runtime config: feature flags, endpoints, tuning knobs.
# ECS task definition reads these via the `environment` block (plaintext injection).
# Pattern: /project/env/category/key → container env var at startup.
resource "aws_ssm_parameter" "string" {
  for_each = var.string_parameters

  name  = "/${var.project}/${var.environment}/${each.key}"
  type  = "String"
  value = each.value

  tags = merge(local.common_tags, {
    Name = "/${var.project}/${var.environment}/${each.key}"
  })
}

# ── SecureString parameters ────────────────────────────────────────────────────
# Sensitive config that doesn't warrant full Secrets Manager rotation:
# internal API keys, third-party webhook tokens, non-rotated credentials.
# ECS reads these via the `secrets` block — value is decrypted at container start,
# injected as env vars. The task execution role must have ssm:GetParameters.
# In real AWS: pass kms_key_id to encrypt with a CMK (not the AWS default key).
resource "aws_ssm_parameter" "secure" {
  # nonsensitive() exposes the map keys (parameter names) as resource identifiers.
  # The keys are not secret — they're just paths like "config/internal-api-key".
  # The values remain sensitive inside each resource's `value` attribute.
  for_each = nonsensitive(var.secure_parameters)

  name  = "/${var.project}/${var.environment}/${each.key}"
  type  = "SecureString"
  value = each.value

  # key_id omitted — Ministack uses a default KMS key.
  # Real AWS: key_id = var.kms_key_id for CMK encryption.

  tags = merge(local.common_tags, {
    Name = "/${var.project}/${var.environment}/${each.key}"
  })
}
