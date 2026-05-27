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
  source = "../../../modules/secret-manager"
}

dependency "iam" {
  config_path = "../iam"
  mock_outputs = {
    service_account_emails = {
      app = "platform-zero-dev-app@gcplab-dev.iam.gserviceaccount.com"
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  project    = "platform-zero"
  environment = local.environment
  project_id  = local.gcp_project

  # Secrets named: platform-zero-dev-{key}
  # In real GCP: values come from a secrets backend or CI secrets injection,
  # never hardcoded in terragrunt.hcl.
  secrets = {
    db-password    = "dev-postgres-password-change-in-prod"
    api-key        = "dev-internal-api-key-placeholder"
    webhook-secret = "dev-webhook-signing-secret-placeholder"
  }

  accessor_service_account = dependency.iam.outputs.service_account_emails["app"]
}
