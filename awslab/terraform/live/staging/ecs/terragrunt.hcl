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
    ci_deploy_role_arn      = "arn:aws:iam::000000000002:role/mock-ci-deploy"
    permission_boundary_arn = "arn:aws:iam::000000000002:policy/mock-boundary"
  }
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    private_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
  }
}

dependency "alb" {
  config_path = "../alb"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:000000000002:targetgroup/mock/0000000000000000"
    ecs_sg_id        = "sg-00000000000000000"
  }
}

inputs = {
  environment = "staging"

  permission_boundary_arn = ""

  launch_type  = "EC2"
  network_mode = "awsvpc"

  container_image = "nginx:alpine"
  container_port  = 80

  # Staging: 2 replicas to simulate HA behaviour.
  desired_count = 2
  cpu           = 256
  memory        = 512

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  target_group_arn        = dependency.alb.outputs.target_group_arn
  subnet_ids              = dependency.vpc.outputs.private_subnet_ids
  task_security_group_ids = [dependency.alb.outputs.ecs_sg_id]

  # Staging account is 000000000002.
  sqs_queue_arns  = ["arn:aws:sqs:us-east-1:000000000002:platform-zero-staging-orders"]
  rds_secret_arns = ["arn:aws:secretsmanager:us-east-1:000000000002:secret:platform-zero/staging/rds/*"]
}
