include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/cloudwatch"
}

dependency "ecs" {
  config_path = "../ecs"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    cluster_name = "platform-zero-dev"
    service_name = "platform-zero"
  }
}

dependency "sqs" {
  config_path = "../sqs"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    dlq_name = "platform-zero-dev-orders-dlq"
  }
}

dependency "rds" {
  config_path = "../rds"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    db_identifier = "platform-zero-dev"
  }
}

dependency "alb" {
  config_path = "../alb"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    arn_suffix = "app/platform-zero-dev/0000000000000000"
  }
}

inputs = {
  environment = "dev"

  ecs_cluster_name = dependency.ecs.outputs.cluster_name
  ecs_service_name = dependency.ecs.outputs.service_name
  sqs_dlq_name     = dependency.sqs.outputs.dlq_name
  rds_instance_id  = dependency.rds.outputs.db_identifier
  alb_arn_suffix   = dependency.alb.outputs.arn_suffix

  # Thresholds — relaxed for lab (dev traffic is low).
  ecs_cpu_threshold_pct    = 80
  ecs_memory_threshold_pct = 80
  rds_connection_threshold = 50
  alb_5xx_threshold_pct    = 10

  alarm_period       = 60
  evaluation_periods = 2

  # No SNS topic in lab — alarms fire but no notification goes out.
  # Prod: wire an SNS topic ARN to trigger PagerDuty or Slack.
  alarm_actions = []
}
