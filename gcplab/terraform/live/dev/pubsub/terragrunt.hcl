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
  source = "../../../modules/pubsub"
}

dependency "iam" {
  config_path = "../iam"
  mock_outputs = {
    service_account_emails = {
      app    = "platform-zero-dev-app@gcplab-dev.iam.gserviceaccount.com"
      worker = "platform-zero-dev-worker@gcplab-dev.iam.gserviceaccount.com"
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  project    = "platform-zero"
  environment = local.environment
  project_id  = local.gcp_project

  topic_name = "orders"

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s" # 7 days
  max_delivery_attempts      = 5
  retry_minimum_backoff      = "10s"
  retry_maximum_backoff      = "300s"

  publisher_service_account  = dependency.iam.outputs.service_account_emails["app"]
  subscriber_service_account = dependency.iam.outputs.service_account_emails["worker"]
}
