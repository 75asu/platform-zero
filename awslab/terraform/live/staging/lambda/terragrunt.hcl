include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/lambda"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_id             = "vpc-00000001"
    private_subnet_ids = ["subnet-00000003", "subnet-00000004"]
  }
}

dependency "s3" {
  config_path = "../s3"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    bucket_arn = "arn:aws:s3:::mock-bucket-staging"
    bucket_id  = "mock-bucket-staging"
  }
}

dependency "sqs" {
  config_path = "../sqs"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    queue_arn = "arn:aws:sqs:us-east-1:000000000002:mock-queue"
  }
}

dependency "ssm" {
  config_path = "../ssm"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    all_parameter_arns = ["arn:aws:ssm:us-east-1:000000000002:parameter/mock"]
  }
}

inputs = {
  environment = "staging"

  runtime          = "python3.12"
  function_timeout = 60
  memory_size      = 512  # more memory in staging — closer to prod sizing
  log_level        = "WARN"

  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids

  s3_bucket_arn    = dependency.s3.outputs.bucket_arn
  s3_bucket_id     = dependency.s3.outputs.bucket_id
  s3_filter_prefix = ""
  s3_filter_suffix = ""

  sqs_queue_arns     = [dependency.sqs.outputs.queue_arn]
  ssm_parameter_arns = dependency.ssm.outputs.all_parameter_arns

  sns_topic_arn  = "arn:aws:sns:us-east-1:000000000002:platform-zero-staging-orders"
  sqs_batch_size = 10

  extra_env_vars = {
    REDIS_ENDPOINT = "/platform-zero/staging/redis/endpoint"
  }
}
