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
  source = "../../../modules/gcs"
}

dependency "iam" {
  config_path = "../iam"
  mock_outputs = {
    service_account_emails = { app = "platform-zero-dev-app@gcplab-dev.iam.gserviceaccount.com" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  project    = "platform-zero"
  environment = local.environment
  project_id  = local.gcp_project

  bucket_suffix      = "assets"
  location           = "US"
  storage_class      = "STANDARD"
  versioning_enabled = false
  force_destroy      = true

  # Delete objects older than 30 days — keeps the dev bucket lean.
  lifecycle_rules = [
    {
      action_type = "Delete"
      age_days    = 30
    }
  ]

  iam_members = {
    app_writer = {
      role   = "roles/storage.objectCreator"
      member = "serviceAccount:${dependency.iam.outputs.service_account_emails["app"]}"
    }
    app_reader = {
      role   = "roles/storage.objectViewer"
      member = "serviceAccount:${dependency.iam.outputs.service_account_emails["worker"]}"
    }
  }
}
