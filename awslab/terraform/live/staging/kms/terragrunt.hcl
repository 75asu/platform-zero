include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/kms"
}

inputs = {
  environment = "staging"

  key_alias               = "main"
  deletion_window_in_days = 7

  allowed_services = ["rds.amazonaws.com", "elasticache.amazonaws.com"]
}
