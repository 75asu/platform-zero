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
  source = "../../../modules/bigquery"
}

inputs = {
  project     = "platform-zero"
  environment = local.environment
  project_id  = local.gcp_project

  dataset_id = "events"
  location   = "US"

  tables = {
    raw_events = {
      schema = jsonencode([
        { name = "event_id",   type = "STRING",    mode = "REQUIRED" },
        { name = "event_type", type = "STRING",    mode = "REQUIRED" },
        { name = "user_id",    type = "STRING",    mode = "NULLABLE" },
        { name = "payload",    type = "JSON",      mode = "NULLABLE" },
        { name = "created_at", type = "TIMESTAMP", mode = "REQUIRED" },
      ])
    }
    processed_events = {
      schema = jsonencode([
        { name = "event_id",    type = "STRING",    mode = "REQUIRED" },
        { name = "event_type",  type = "STRING",    mode = "REQUIRED" },
        { name = "user_id",     type = "STRING",    mode = "NULLABLE" },
        { name = "result",      type = "STRING",    mode = "NULLABLE" },
        { name = "processed_at", type = "TIMESTAMP", mode = "REQUIRED" },
      ])
    }
  }
}
