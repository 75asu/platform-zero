include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/ecs"
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

  # Ministack: EC2 launch type + awsvpc network mode with fake subnets.
  # Bridge mode crashes aws provider v4/v5 (nil NetworkConfiguration).
  # Ministack accepts awsvpc with dummy subnet IDs.
  # Real AWS staging: FARGATE + real VPC subnets.
  launch_type  = "EC2"
  network_mode = "awsvpc"

  container_image = "nginx:alpine"
  container_port  = 80

  # Staging runs 2 replicas — simulates HA behavior even in Ministack.
  desired_count = 2
  cpu           = 256
  memory        = 512

  # Rolling deploy config: stop 50% of old tasks before starting new ones.
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  create_alb = false

  # Staging account is 000000000002 (Ministack multi-env isolation via access_key).
  sqs_queue_arns  = ["arn:aws:sqs:us-east-1:000000000002:platform-zero-staging-orders"]
  rds_secret_arns = ["arn:aws:secretsmanager:us-east-1:000000000002:secret:platform-zero/staging/rds/*"]

  # Ministack awsvpc: fake subnet + security group IDs.
  # Real AWS: use real VPC subnet IDs.
  subnet_ids              = ["subnet-fake123"]
  task_security_group_ids  = ["sg-fake456"]
  alb_security_group_ids   = []
}
