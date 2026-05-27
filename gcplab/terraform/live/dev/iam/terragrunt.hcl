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
  source = "../../../modules/iam"
}

inputs = {
  project    = "platform-zero"
  environment = local.environment
  project_id  = local.gcp_project

  # One service account per logical service.
  # In real GCP: each SA gets the minimal permissions its service needs.
  service_accounts = {
    app    = {}
    worker = {}
    ci     = {}
  }

  # Custom role: least-privilege set shared across app service accounts.
  # Covers: GCS read/write, Pub/Sub publish + subscribe, Secret Manager access, Cloud SQL connect.
  custom_role_permissions = [
    "storage.objects.get",
    "storage.objects.create",
    "storage.objects.delete",
    "storage.objects.list",
    "pubsub.topics.publish",
    "pubsub.subscriptions.consume",
    "pubsub.subscriptions.get",
    "secretmanager.versions.access",
    "cloudsql.instances.connect",
    "run.routes.invoke",
  ]
}
