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
  environment = "dev"

  # Dev: smallest viable instance, no multi-AZ, short backup retention.
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  backup_retention_period = 1

  # Ministack: create_subnet_group = false (Ministack subnet groups are not functional).
  # In real AWS: create_subnet_group = true, subnet_ids = dependency.vpc.outputs.data_subnet_ids
  create_subnet_group = false
  subnet_ids          = dependency.vpc.outputs.data_subnet_ids

  # Ministack: storage_encrypted = false (no KMS support).
  # In real AWS: set true.
  storage_encrypted = false

  # Slow query log: 1 second threshold in dev.
  log_min_duration_statement = "1000"

  # Lab credential — never commit real passwords.
  # In real AWS: pull from CI env var: TF_VAR_db_password = ${{ secrets.DB_PASSWORD }}
  db_password = "devpassword123!"
}
