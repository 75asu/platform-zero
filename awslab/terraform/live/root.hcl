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
      # ~> 5.99.1: provider 5.99.1 ignores InvalidAction on DescribeCapacityReservation
      # (PR #42812), which is what Ministack returns for that ALB call.
      # Upper bound < 5.100: provider 5.100+ switched CloudWatch to CBOR binary
      # encoding; Ministack v1.3.43 speaks JSON only → DescribeAlarms fails.
      # Ministack implements DescribeListenerAttributes natively (since v1.2.8).
      # Real AWS: remove both constraints.
      version = "~> 5.99.1"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
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
    s3                = "${local.aws_endpoint}"
    dynamodb          = "${local.aws_endpoint}"
    sqs               = "${local.aws_endpoint}"
    rds               = "${local.aws_endpoint}"
    secretsmanager    = "${local.aws_endpoint}"
    iam               = "${local.aws_endpoint}"
    sts               = "${local.aws_endpoint}"
    ecs               = "${local.aws_endpoint}"
    ecr               = "${local.aws_endpoint}"
    cloudwatchlogs    = "${local.aws_endpoint}"
    cloudwatch        = "${local.aws_endpoint}"
    elasticache       = "${local.aws_endpoint}"
    kms               = "${local.aws_endpoint}"
    elbv2             = "${local.aws_endpoint}"
    ssm               = "${local.aws_endpoint}"
    sns               = "${local.aws_endpoint}"
    lambda            = "${local.aws_endpoint}"
    scheduler         = "${local.aws_endpoint}"
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
