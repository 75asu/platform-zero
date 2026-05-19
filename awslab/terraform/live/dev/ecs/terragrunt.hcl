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
    ci_deploy_role_arn      = "arn:aws:iam::000000000000:role/mock-ci-deploy"
    permission_boundary_arn = "arn:aws:iam::000000000000:policy/mock-boundary"
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
    target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:000000000000:targetgroup/mock/0000000000000000"
    ecs_sg_id        = "sg-00000000000000000"
  }
}

inputs = {
  environment = "dev"

  permission_boundary_arn = ""

  launch_type  = "EC2"
  network_mode = "awsvpc"

  container_image = "nginx:alpine"
  container_port  = 80

  desired_count = 1
  cpu           = 256
  memory        = 512

  # Prod: false — tasks in private subnets, NAT for outbound.
  # Ministack: no VPC/ENI allocation, value has no effect.
  assign_public_ip = false

  # Enable ECS Exec for debugging (equivalent to kubectl exec).
  # Dev: true. Prod: false (audit risk).
  enable_execute_command = true

  # ALB wired via alb module — target group and ECS SG from its outputs.
  target_group_arn        = dependency.alb.outputs.target_group_arn
  subnet_ids              = dependency.vpc.outputs.private_subnet_ids
  task_security_group_ids = [dependency.alb.outputs.ecs_sg_id]

  sqs_queue_arns  = ["arn:aws:sqs:us-east-1:000000000000:platform-zero-dev-orders"]
  rds_secret_arns = ["arn:aws:secretsmanager:us-east-1:000000000000:secret:platform-zero/dev/rds/*"]

  # Secrets pulled from Secrets Manager at task startup (injected as env vars by ECS agent).
  # Format: valueFrom = secret ARN or ARN with JSON key suffix (e.g. arn:...:secret:name::key::)
  container_secrets = [
    {
      name      = "DB_PASSWORD"
      valueFrom = "arn:aws:secretsmanager:us-east-1:000000000000:secret:platform-zero/dev/rds/credentials"
    }
  ]
}
