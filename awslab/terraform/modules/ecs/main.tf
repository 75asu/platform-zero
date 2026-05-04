locals {
  name = "${var.project}-${var.environment}"

  # ALB target type depends on network mode:
  # awsvpc → each task has its own IP → target by IP
  # bridge/host → tasks share the EC2 instance IP → target by instance
  alb_target_type = var.network_mode == "awsvpc" ? "ip" : "instance"

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

# ── ALB ────────────────────────────────────────────────────────────────────────
# Application Load Balancer: HTTP(S) routing, health checks, sticky sessions.
# Skipped in Ministack (create_alb = false) because ALB placement requires VPC subnets.
# In real AWS: always use ALB in front of ECS services — never expose tasks directly.
resource "aws_lb" "this" {
  count = var.create_alb ? 1 : 0

  name               = local.name
  internal           = false
  load_balancer_type = "application"
  security_groups    = length(var.alb_security_group_ids) > 0 ? var.alb_security_group_ids : null
  subnets            = length(var.subnet_ids) > 0 ? var.subnet_ids : null

  tags = merge(local.common_tags, {
    Name = local.name
  })
}

resource "aws_lb_target_group" "this" {
  count = var.create_alb ? 1 : 0

  name        = local.name
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id != "" ? var.vpc_id : null
  target_type = local.alb_target_type

  health_check {
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = merge(local.common_tags, {
    Name = local.name
  })
}

resource "aws_lb_listener" "http" {
  count = var.create_alb ? 1 : 0

  load_balancer_arn = aws_lb.this[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[0].arn
  }
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

  # awsvpc only — bridge mode has no per-task network config.
  dynamic "network_configuration" {
    for_each = var.network_mode == "awsvpc" ? [1] : []
    content {
      subnets          = var.subnet_ids
      security_groups  = var.task_security_group_ids
      assign_public_ip = true
    }
  }

  # Wire service to ALB when enabled.
  dynamic "load_balancer" {
    for_each = var.create_alb ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.this[0].arn
      container_name   = var.project
      container_port   = var.container_port
    }
  }

  # Listener must exist before the service — ECS validates ALB registration on create.
  depends_on = [aws_lb_listener.http]

  tags = merge(local.common_tags, {
    Name = local.name
  })
}
