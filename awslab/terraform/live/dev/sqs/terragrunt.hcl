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
    ci_deploy_role_arn = "arn:aws:iam::000000000000:role/mock-ci-deploy"
  }
}

inputs = {
  environment = "dev"
  queue_name  = "orders"

  # Standard queue defaults — demonstrating the key knobs:
  #   visibility_timeout_seconds: 30s (consumer has 30s to process before re-delivery)
  #   receive_wait_time_seconds: 20  (long polling — no extra cost from empty receives)
  #   max_receive_count: 3           (3 failures → DLQ quarantine)

  # Terragrunt cannot resolve dependency outputs inside list literals.
  # Hardcoding the known ARN here — matches what dependency.iam.outputs.ci_deploy_role_arn
  # would return. In real AWS, use a data source or pass via CI env var instead.
  allowed_sender_arns   = ["arn:aws:iam::000000000000:role/platform-zero-dev-ci-deploy"]
  allowed_consumer_arns = ["arn:aws:iam::000000000000:role/platform-zero-dev-ci-deploy"]
}
