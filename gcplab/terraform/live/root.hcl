locals {
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  environment    = local.project_vars.locals.environment
  gcp_project    = local.project_vars.locals.gcp_project
  minisky_endpoint = local.project_vars.locals.minisky_endpoint

  minio_endpoint = get_env("MINIO_ENDPOINT_URL", "http://localhost:9002")
}

# Generates provider.tf in every module's working directory.
# MiniSky uses the official google provider with per-service endpoint overrides.
# GOOGLE_OAUTH_ACCESS_TOKEN is set in env.sh — provider picks it up automatically.
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

  # MiniSky: override each service endpoint to the local emulator.
  # Add more overrides here as modules are built for those services.
  storage_custom_endpoint        = "${local.minisky_endpoint}/storage/v1/"
  compute_custom_endpoint        = "${local.minisky_endpoint}/compute/v1/"
  pubsub_custom_endpoint         = "${local.minisky_endpoint}/"
  bigquery_custom_endpoint       = "${local.minisky_endpoint}/bigquery/v2/"
  cloud_run_v2_custom_endpoint   = "${local.minisky_endpoint}/v2/"
  firestore_custom_endpoint      = "${local.minisky_endpoint}/"
}
EOF
}

# State lives in MinIO (S3-compatible API).
# No DynamoDB locking — MinIO doesn't support it.
# In real GCP: switch to gcs backend with built-in object locking.
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

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
  }
}
