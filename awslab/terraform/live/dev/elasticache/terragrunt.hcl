include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/elasticache"
}

inputs = {
  environment = "dev"

  node_type            = "cache.t3.micro"
  num_cache_clusters   = 1
  engine_version       = "7.0"
  parameter_group_name = "default.redis7"

  # Floci has no VPC subnet groups needed for the emulated endpoint.
  create_subnet_group = false
  subnet_ids          = []
  security_group_ids  = []

  # Encryption: disabled in lab. Prod: both true, with KMS CMK for at-rest.
  at_rest_encryption_enabled = false
  transit_encryption_enabled = false

  # HA: disabled in lab (single node). Prod: num_cache_clusters = 2,
  # automatic_failover_enabled = true, multi_az_enabled = true.
  automatic_failover_enabled = false
  multi_az_enabled           = false

  snapshot_retention_limit = 0
  apply_immediately        = true
}
