include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "project" {
  path = find_in_parent_folders("project.hcl")
}

locals {
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))
  environment  = local.project_vars.locals.environment
  gcp_project  = local.project_vars.locals.gcp_project
}

terraform {
  source = "../../../modules/cloudsql"
}

inputs = {
  project    = "platform-zero"
  environment = local.environment
  project_id  = local.gcp_project

  region           = "us-central1"
  database_version = "POSTGRES_15"
  tier             = "db-g1-small"

  database_name = "app"
  db_user       = "app"
  db_password   = "staging-postgres-password-change-in-prod"

  database_flags = {
    "max_connections"             = "200"
    "log_min_duration_statement"  = "200"
  }

  backup_enabled = true
}
