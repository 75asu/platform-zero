include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/sqs"
}

dependency "iam" {
  config_path = "../iam"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    ci_deploy_role_arn = "arn:aws:iam::000000000002:role/mock-ci-deploy"
  }
}

inputs = {
  environment = "staging"
  queue_name  = "orders"

  # Staging: longer retention and higher max_receive_count than dev —
  # messages that fail in staging need more investigation time before DLQ.
  message_retention_seconds = 604800 # 7 days (dev: 4 days)
  max_receive_count         = 5      # (dev: 3)

  # Staging account is 000000000002 — different namespace from dev (000000000000).
  # Demonstrates environment isolation: staging queue policy references staging IAM role,
  # dev CI cannot assume staging roles and vice versa.
  allowed_sender_arns   = ["arn:aws:iam::000000000002:role/platform-zero-staging-ci-deploy"]
  allowed_consumer_arns = ["arn:aws:iam::000000000002:role/platform-zero-staging-ci-deploy"]
}
