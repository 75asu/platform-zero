include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/sns"
}

dependency "sqs" {
  config_path = "../sqs"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    queue_arn = "arn:aws:sqs:us-east-1:000000000000:mock-queue"
  }
}

dependency "lambda" {
  config_path = "../lambda"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    analytics_queue_arn = "arn:aws:sqs:us-east-1:000000000000:mock-analytics-queue"
  }
}

dependency "iam" {
  config_path = "../iam"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    ci_deploy_role_arn = "arn:aws:iam::000000000000:role/mock-ci-deploy"
  }
}

inputs = {
  environment = "dev"
  topic_name  = "orders"

  # ECS task role and CI deploy role can publish order events to this topic.
  # Terragrunt can't resolve dependency outputs inside list literals —
  # hardcode the known ARNs (match what iam module creates for dev).
  publisher_arns = [
    "arn:aws:iam::000000000000:role/platform-zero-dev-ecs-task",
    "arn:aws:iam::000000000000:role/platform-zero-dev-ci-deploy",
  ]

  # Two SQS subscribers:
  # 1. orders queue   — existing fulfilment worker (ECS reads from this)
  # 2. analytics queue — new Lambda analytics consumer
  sqs_subscriber_arns = [
    dependency.sqs.outputs.queue_arn,
    dependency.lambda.outputs.analytics_queue_arn,
  ]
}
