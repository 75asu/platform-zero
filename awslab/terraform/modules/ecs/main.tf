locals {
  name = "${var.project}-${var.environment}"

  # bridge mode uses dynamic host port (0) so ECS picks a free port.
  # awsvpc mode omits hostPort — the containerPort IS the accessible port.
  host_port = var.network_mode == "bridge" ? 0 : var.container_port

  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# ── CloudWatch log group ───────────────────────────────────────────────────────
# Create explicitly so Terraform owns the lifecycle (and can set retention).
# Without this, ECS auto-creates it with no retention policy → unbounded cost.
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${local.name}"
  retention_in_days = 7

  tags = merge(local.common_tags, {
    Name = "/ecs/${local.name}"
  })
}

# ── ECR repository ─────────────────────────────────────────────────────────────
# Private image registry. Push here, reference in task definition.
# image_tag_mutability = MUTABLE: overwrite :latest tag freely in dev/staging.
# In prod: IMMUTABLE — forces unique tags (git SHA), prevents silent rollback.
resource "aws_ecr_repository" "this" {
  name                 = local.name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, {
    Name = local.name
  })
}

# ── ECS cluster ────────────────────────────────────────────────────────────────
resource "aws_ecs_cluster" "this" {
  name = local.name

  tags = merge(local.common_tags, {
    Name = local.name
  })
}

# ── Task definition ────────────────────────────────────────────────────────────
# The immutable spec for your container: image, CPU, memory, ports, IAM roles.
# Each deploy creates a new revision — ECS keeps history for rollbacks.
resource "aws_ecs_task_definition" "this" {
  family                   = local.name
  requires_compatibilities = [var.launch_type]
  network_mode             = var.network_mode
  cpu                      = var.cpu
  memory                   = var.memory

  # execution_role: ECS agent uses this to pull the image and write logs.
  # task_role: the running app uses this to call AWS APIs.
  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name  = var.project
      image = var.container_image

      portMappings = [{
        containerPort = var.container_port
        hostPort      = local.host_port
        protocol      = "tcp"
      }]

      environment = var.container_environment

      # Secrets pulled from Secrets Manager at task startup by the ECS agent.
      # Injection pattern: ECS agent calls GetSecretValue, injects as env var.
      # App code reads a plain env var — never calls Secrets Manager directly.
      # This is safer than passing secret ARNs to var.container_environment.
      secrets = var.container_secrets

      # Structured JSON logs routed to CloudWatch Logs.
      # awslogs-stream-prefix groups streams by task ID under this prefix.
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential = true
    }
  ])

  tags = merge(local.common_tags, {
    Name = local.name
  })
}

# ── ECS service ────────────────────────────────────────────────────────────────
# The service maintains desired_count running task replicas.
# On task failure ECS automatically replaces it.
# On new task definition revision: rolling deploy using min/max percent config.
resource "aws_ecs_service" "this" {
  name            = var.project
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = var.launch_type

  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent

  # ECS Exec: opens an interactive shell into a running task via SSM Session Manager.
  # Equivalent to kubectl exec — use for debugging without exposing SSH.
  # Requires: SSM agent in container image + ssmmessages permissions on task role.
  # Real AWS: enable in dev/staging for debugging. Prod: disable (audit risk).
  # Ministack: setting this has no effect — SSM channel is not simulated.
  enable_execute_command = var.enable_execute_command

  # awsvpc only — bridge mode has no per-task network config.
  dynamic "network_configuration" {
    for_each = var.network_mode == "awsvpc" ? [1] : []
    content {
      subnets          = var.subnet_ids
      security_groups  = var.task_security_group_ids
      # Prod: false — tasks in private subnets, outbound via NAT Gateway.
      # Ministack: true is safe (no real NAT), but default is now false to match prod intent.
      assign_public_ip = var.assign_public_ip
    }
  }

  # Wire service to ALB target group when provided.
  # target_group_arn comes from the alb module output.
  dynamic "load_balancer" {
    for_each = var.target_group_arn != "" ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.project
      container_port   = var.container_port
    }
  }

  tags = merge(local.common_tags, {
    Name = local.name
  })
}
