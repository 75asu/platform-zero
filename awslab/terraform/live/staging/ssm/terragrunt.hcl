include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/ssm"
}

inputs = {
  environment = "staging"

  string_parameters = {
    "config/log-level"       = "WARN"
    "config/max-connections" = "50"
    "config/feature-flags"   = "analytics:true,webhooks:true"
    "redis/endpoint"         = "localhost:6379"
  }

  secure_parameters = {
    "config/internal-api-key" = "staging-api-key-replace-in-real-aws"
    "config/webhook-secret"   = "staging-webhook-secret-replace-in-real-aws"
  }
}
