locals {
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  environment    = local.project_vars.locals.environment
  gcp_project    = local.project_vars.locals.gcp_project

  minio_endpoint  = get_env("MINIO_ENDPOINT_URL", "http://localhost:9002")

  # nginx reverse proxy rewrites Host headers per port so MiniSky sees
  # the correct GCP domain — same pattern as awslab pointing at Ministack.
  proxy_host = get_env("TARGET_HOST", "localhost")
}

# Generates provider.tf in every module's working directory.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "${local.gcp_project}"
  region  = "us-central1"

  # nginx proxy (gcplab-minisky-proxy) listens on per-service ports and
  # rewrites the Host header before forwarding to MiniSky on 8082.
  # No /etc/hosts overrides or iptables rules needed on the local machine.
  storage_custom_endpoint           = "http://${local.proxy_host}:8090/storage/v1/"
  iam_custom_endpoint               = "http://${local.proxy_host}:8091/"
  pubsub_custom_endpoint            = "http://${local.proxy_host}:8093/"
  secret_manager_custom_endpoint    = "http://${local.proxy_host}:8094/"
  sql_custom_endpoint               = "http://${local.proxy_host}:8095/"
  artifact_registry_custom_endpoint = "http://${local.proxy_host}:8096/"
  cloud_run_v2_custom_endpoint      = "http://${local.proxy_host}:8097/"
  container_custom_endpoint         = "http://${local.proxy_host}:8098/"
  big_query_custom_endpoint         = "http://${local.proxy_host}:8099/"
}
EOF
}

# State lives in MinIO (S3-compatible API).
# No DynamoDB locking — MinIO does not support it.
# In real GCP: switch to gcs backend which has built-in object locking.
remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket = "platform-zero-gcp-tfstate"
    key    = "live/${path_relative_to_include()}/terraform.tfstate"
    region = "us-east-1"

    access_key = "minioadmin"
    secret_key = "minioadmin"

    endpoint         = local.minio_endpoint
    force_path_style = true

    skip_credentials_validation  = true
    skip_metadata_api_check      = true
    skip_region_validation       = true
    skip_requesting_account_id   = true
  }
}
