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
    queue_arn = "arn:aws:sqs:us-east-1:000000000002:mock-queue"
  }
}

dependency "lambda" {
  config_path = "../lambda"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    analytics_queue_arn = "arn:aws:sqs:us-east-1:000000000002:mock-analytics-queue"
  }
}

inputs = {
  environment = "staging"
  topic_name  = "orders"

  publisher_arns = [
    "arn:aws:iam::000000000002:role/platform-zero-staging-ecs-task",
    "arn:aws:iam::000000000002:role/platform-zero-staging-ci-deploy",
  ]

  sqs_subscriber_arns = [
    dependency.sqs.outputs.queue_arn,
    dependency.lambda.outputs.analytics_queue_arn,
  ]
}
