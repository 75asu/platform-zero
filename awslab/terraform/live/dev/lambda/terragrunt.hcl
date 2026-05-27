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
    vpc_id             = "vpc-00000000"
    private_subnet_ids = ["subnet-00000001", "subnet-00000002"]
  }
}

dependency "s3" {
  config_path = "../s3"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    bucket_arn = "arn:aws:s3:::mock-bucket"
    bucket_id  = "mock-bucket"
  }
}

dependency "sqs" {
  config_path = "../sqs"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    queue_arn = "arn:aws:sqs:us-east-1:000000000000:mock-queue"
  }
}

dependency "ssm" {
  config_path = "../ssm"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    all_parameter_arns = ["arn:aws:ssm:us-east-1:000000000000:parameter/mock"]
  }
}

inputs = {
  environment = "dev"

  runtime         = "python3.12"
  function_timeout = 60
  memory_size     = 256
  log_level       = "INFO"

  # VPC attachment: private subnets only.
  # Lambda in VPC = slower cold starts + NAT needed for internet.
  # Required here for ElastiCache access once it's re-enabled.
  # Ministack: VPC SG and subnet wiring is applied but not enforced.
  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids

  # S3 trigger — s3_processor fires on every object creation in the app bucket.
  s3_bucket_arn = dependency.s3.outputs.bucket_arn
  s3_bucket_id  = dependency.s3.outputs.bucket_id
  s3_filter_prefix = ""   # all prefixes
  s3_filter_suffix = ""   # all suffixes

  # SQS queues the functions can consume from (IAM policy).
  # analytics queue is created inside the module — its ARN is in module output.
  sqs_queue_arns = [dependency.sqs.outputs.queue_arn]

  # SSM: all parameter ARNs — functions can read any config param.
  ssm_parameter_arns = dependency.ssm.outputs.all_parameter_arns

  # SNS topic ARN: analytics queue subscribes to this on apply.
  # Circular: sns needs lambda.analytics_queue_arn, lambda needs sns_topic_arn.
  # Resolution: lambda applies first (creates the queue), sns applies second
  # (subscribes the queue). sns_topic_arn passed here for queue policy only.
  # Terragrunt handles the order via dependency blocks in sns/terragrunt.hcl.
  sns_topic_arn = "arn:aws:sns:us-east-1:000000000000:platform-zero-dev-orders"

  # Batch size: 10 messages per Lambda invocation.
  sqs_batch_size = 10

  extra_env_vars = {
    REDIS_ENDPOINT = "/platform-zero/dev/redis/endpoint"
  }
}
