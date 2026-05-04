include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/rds"
}

inputs = {
  environment = "dev"

  # Dev: smallest viable instance, no multi-AZ, short backup retention.
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  backup_retention_period = 1

  # Ministack: create_subnet_group = false (no VPC support).
  # In real AWS: set true and wire subnet_ids from VPC module outputs.
  create_subnet_group = false

  # Ministack: storage_encrypted = false (no KMS support).
  # In real AWS: set true.
  storage_encrypted = false

  # Slow query log: 1 second threshold in dev.
  log_min_duration_statement = "1000"

  # Lab credential — never commit real passwords.
  # In real AWS: pull from CI env var: TF_VAR_db_password = ${{ secrets.DB_PASSWORD }}
  db_password = "devpassword123!"
}
