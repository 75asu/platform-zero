include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/rds"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_id          = "vpc-00000000000000000"
    data_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
  }
}

inputs = {
  environment = "staging"

  # Staging: slightly more headroom than dev — catches connection pool issues
  # before they hit prod. Still not multi-AZ (cost).
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  backup_retention_period = 3
  max_connections         = "150"

  # Staging: tighter slow query threshold — surface marginal queries early.
  log_min_duration_statement = "500"

  # Ministack: create_subnet_group = false (Ministack subnet groups are not functional).
  # In real AWS: create_subnet_group = true, subnet_ids = dependency.vpc.outputs.data_subnet_ids
  create_subnet_group = false
  subnet_ids          = dependency.vpc.outputs.data_subnet_ids

  # Ministack: storage_encrypted = false (no KMS support).
  # In real AWS: set true.
  storage_encrypted = false

  # Lab credential — never commit real passwords.
  db_password = "stagingpassword456!"
}
