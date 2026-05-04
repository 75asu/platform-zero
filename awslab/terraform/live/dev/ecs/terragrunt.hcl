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
    ci_deploy_role_arn = "arn:aws:iam::000000000000:role/mock-ci-deploy"
  }
}

inputs = {
  environment = "dev"

  # Ministack: EC2 launch type + awsvpc network mode with fake subnets.
  # Bridge mode crashes aws provider v4/v5 (nil NetworkConfiguration).
  # Ministack accepts awsvpc with dummy subnet IDs.
  # Real AWS: switch to FARGATE + real VPC subnets.
  launch_type  = "EC2"
  network_mode = "awsvpc"

  # nginx:alpine as the default image — validates the ECS service lifecycle
  # without needing a real application image pushed to ECR.
  container_image = "nginx:alpine"
  container_port  = 80

  desired_count = 1
  cpu           = 256
  memory        = 512

  # Ministack: ALB requires real VPC subnets for placement — not available here.
  # Real AWS: set true and wire alb_security_group_ids + subnet_ids + vpc_id.
  create_alb = false

  # Wire SQS and RDS outputs into the task role.
  # Ministack: hardcode ARNs — dependency outputs can't resolve in list literals.
  # Real AWS pattern: use data sources or pass via CI env vars.
  sqs_queue_arns  = ["arn:aws:sqs:us-east-1:000000000000:platform-zero-dev-orders"]
  rds_secret_arns = ["arn:aws:secretsmanager:us-east-1:000000000000:secret:platform-zero/dev/rds/*"]

  # Ministack awsvpc: fake subnet + security group IDs.
  # Real AWS: use real VPC subnet IDs.
  subnet_ids              = ["subnet-fake123"]
  task_security_group_ids  = ["sg-fake456"]
  alb_security_group_ids   = []
}
