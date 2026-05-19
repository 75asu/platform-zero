# Excluded from `terragrunt run --all` due to Ministack Go SDK compatibility.
# The Terraform AWS provider polls for ElastiCache cluster status using the Go SDK,
# which behaves differently from the AWS CLI — Ministack supports the CLI but not
# the SDK's describe calls. Apply manually: make tf-elasticache
# In real AWS: remove this exclude block and it applies with everything else.
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
  environment = "dev"

  node_type            = "cache.t3.micro"
  engine_version       = "7.0"
  parameter_group_name = "default.redis7"

  # Ministack has no VPC — subnet group and SGs not applicable.
  create_subnet_group = false
  subnet_ids          = []
  security_group_ids  = []

  snapshot_retention_limit = 0
  apply_immediately        = true

  # Prod note: switch to aws_elasticache_replication_group for:
  #   at_rest_encryption_enabled = true (KMS CMK)
  #   transit_encryption_enabled = true (TLS)
  #   num_cache_clusters = 2 (primary + replica, Multi-AZ)
}
