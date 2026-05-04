include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/rds"
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

  # Ministack: create_subnet_group = false (no VPC support).
  # In real AWS: set true and wire subnet_ids from VPC module outputs.
  create_subnet_group = false

  # Ministack: storage_encrypted = false (no KMS support).
  # In real AWS: set true.
  storage_encrypted = false

  # Lab credential — never commit real passwords.
  db_password = "stagingpassword456!"
}
