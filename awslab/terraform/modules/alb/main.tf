locals {
  name = "${var.project}-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# ── Security group — ALB ───────────────────────────────────────────────────────
# Inbound: HTTP from the internet.
# Outbound: all — ALB needs to reach tasks and perform health checks.
# Note: open egress is safe here because ALB only forwards traffic that arrived
# on the listener; it does not originate traffic on its own.
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "ALB inbound HTTP from internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound for health checks and request forwarding"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-alb"
  })
}

# ── Security group — ECS tasks ─────────────────────────────────────────────────
# Inbound: only from the ALB security group on the container port.
# Nothing on the public internet can reach ECS tasks directly.
# Outbound: unrestricted — tasks need to call AWS APIs, RDS, ElastiCache, etc.
# One-directional SG reference: ECS SG references ALB SG (created first).
resource "aws_security_group" "ecs" {
  name        = "${local.name}-ecs-tasks"
  description = "ECS tasks inbound from ALB SG only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "From ALB SG on container port"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound for AWS API calls RDS ElastiCache"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-ecs-tasks"
  })
}

# ── Application Load Balancer ──────────────────────────────────────────────────
# Internet-facing by default. Placed in public subnets across AZs.
# Security group restricts inbound to HTTP only.
resource "aws_lb" "this" {
  name               = local.name
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = merge(local.common_tags, {
    Name = local.name
  })
}

# ── Target group ───────────────────────────────────────────────────────────────
# IP target type is required for awsvpc network mode (each ECS task has its own IP).
# ECS registers task IPs automatically when the service is associated with this TG.
resource "aws_lb_target_group" "this" {
  name        = local.name
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = var.deregistration_delay

  health_check {
    path                = var.health_check_path
    matcher             = var.health_check_matcher
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
  }

  dynamic "stickiness" {
    for_each = var.stickiness_enabled ? [1] : []
    content {
      type            = "lb_cookie"
      cookie_duration = var.stickiness_duration
      enabled         = true
    }
  }

  tags = merge(local.common_tags, {
    Name = local.name
  })

  # Target group must be replaced (not updated in-place) when vpc_id changes.
  lifecycle {
    create_before_destroy = true
  }
}

# ── HTTP listener ──────────────────────────────────────────────────────────────
# Port 80 → forward to target group.
# Real AWS: add a port 443 listener with ACM certificate and redirect HTTP → HTTPS.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
