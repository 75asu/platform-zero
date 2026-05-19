include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/kms"
}

inputs = {
  environment = "dev"

  key_alias               = "main"
  deletion_window_in_days = 7

  # Services allowed to use this key for encryption at rest.
  # RDS uses it for storage encryption, ElastiCache for Redis at-rest encryption.
  allowed_services = ["rds.amazonaws.com", "elasticache.amazonaws.com"]
}
