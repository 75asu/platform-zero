# Excluded from `terragrunt run --all` due to Ministack Go SDK compatibility.
# Apply manually: make tf-elasticache
# In real AWS: remove this exclude block.
exclude {
  if      = true
  actions = ["all"]
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/elasticache"
}

inputs = {
  environment = "staging"

  node_type            = "cache.t3.micro"
  engine_version       = "7.0"
  parameter_group_name = "default.redis7"

  create_subnet_group = false
  subnet_ids          = []
  security_group_ids  = []

  snapshot_retention_limit = 0
  apply_immediately        = true
}
