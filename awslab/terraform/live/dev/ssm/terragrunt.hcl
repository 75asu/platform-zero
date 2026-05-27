include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/ssm"
}

inputs = {
  environment = "dev"

  # Non-sensitive runtime config — stored as plaintext String parameters.
  # ECS task definition reads these via the `environment` block at container start.
  string_parameters = {
    "config/log-level"       = "INFO"
    "config/max-connections" = "25"
    "config/feature-flags"   = "analytics:true,webhooks:false"
    # Placeholder: will be replaced with the real ElastiCache endpoint once
    # ElastiCache is re-enabled (currently disabled due to Darwin SIGBUS bug).
    "redis/endpoint"         = "localhost:6379"
  }

  # Sensitive config — stored encrypted as SecureString.
  # ECS reads via `secrets` block: decrypted by execution role at container start.
  # Not for DB passwords (those live in Secrets Manager + RDS module).
  # Use SSM SecureString for: API keys, internal tokens, feature flags with auth.
  secure_parameters = {
    "config/internal-api-key" = "dev-api-key-replace-in-real-aws"
    "config/webhook-secret"   = "dev-webhook-secret-replace-in-real-aws"
  }
}
