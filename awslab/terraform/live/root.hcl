locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  environment    = local.account_vars.locals.environment
  aws_endpoint   = local.account_vars.locals.aws_endpoint
  access_key     = local.account_vars.locals.access_key

  # MinIO is always the same endpoint regardless of environment — it holds
  # Terraform state only, not app resources.
  minio_endpoint = get_env("MINIO_ENDPOINT_URL", "http://localhost:9000")
}

# Generates provider.tf in every module's working directory.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "${local.access_key}"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3       = "${local.aws_endpoint}"
    dynamodb = "${local.aws_endpoint}"
  }
}
EOF
}

# State lives in MinIO (proper S3 API — no PAB bug).
# Locking uses Ministack's DynamoDB (works correctly).
# Both use access_key = "test" which is the MinIO root user
# and Ministack's bootstrap account.
remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket = "platform-zero-tfstate"
    key    = "live/${path_relative_to_include()}/terraform.tfstate"
    region = "us-east-1"

    access_key = "minioadmin"
    secret_key = "minioadmin"

    # S3 state → MinIO
    endpoint         = local.minio_endpoint
    force_path_style = true

    # DynamoDB locking → Ministack
    dynamodb_endpoint = local.aws_endpoint
    dynamodb_table    = "platform-zero-tfstate-lock"

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
  }
}
