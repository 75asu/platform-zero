variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project tag applied to all resources"
  type        = string
  default     = "platform-zero"
}

variable "aws_region" {
  description = "AWS region — used in CloudWatch log group ARN conditions"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID — used in IAM ARN conditions"
  type        = string
  default     = "000000000000"
}

# ── Container ──────────────────────────────────────────────────────────────────

variable "container_image" {
  description = "Docker image to run. Default is nginx:alpine for lab validation."
  type        = string
  default     = "nginx:alpine"
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
  default     = 80
}

variable "container_environment" {
  description = "Environment variables injected into the container at runtime."
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "cpu" {
  description = "CPU units for the task (1024 = 1 vCPU). Fargate requires specific values."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory in MiB for the task."
  type        = number
  default     = 512
}

# ── Launch configuration ───────────────────────────────────────────────────────

variable "launch_type" {
  description = <<-EOT
    FARGATE: serverless, no EC2 instances to manage. Requires awsvpc network mode.
    EC2: you manage the underlying instances. Supports bridge/host network modes.
    Ministack: use EC2 (Docker socket = bridge mode containers, no VPC).
    Real AWS: use FARGATE for most workloads.
  EOT
  type    = string
  default = "EC2"
}

variable "network_mode" {
  description = <<-EOT
    awsvpc: each task gets its own ENI + private IP (required for Fargate).
    bridge: Docker bridge networking, dynamic host port mapping (EC2 only).
    host: container shares host network stack (EC2 only, highest performance).
    Ministack: use bridge (no VPC, no ENI allocation).
    Real AWS Fargate: use awsvpc.
  EOT
  type    = string
  default = "bridge"
}

variable "desired_count" {
  description = "Number of task replicas the service maintains."
  type        = number
  default     = 1
}

variable "deployment_minimum_healthy_percent" {
  description = <<-EOT
    Minimum % of desired tasks that must stay healthy during a rolling deploy.
    50 = ECS stops half the old tasks, starts new ones, repeats.
    100 = ECS starts new tasks first, then stops old (blue-green-like, needs extra capacity).
  EOT
  type    = number
  default = 50
}

variable "deployment_maximum_percent" {
  description = "Maximum % of desired tasks allowed during a rolling deploy. 200 = double capacity temporarily."
  type        = number
  default     = 200
}

# ── Networking ─────────────────────────────────────────────────────────────────

variable "subnet_ids" {
  description = "Subnets for awsvpc tasks and ALB placement. Empty for Ministack (no VPC)."
  type        = list(string)
  default     = []
}

variable "vpc_id" {
  description = "VPC ID for ALB target group. Empty for Ministack."
  type        = string
  default     = ""
}

variable "task_security_group_ids" {
  description = "Security groups for awsvpc tasks. Empty for Ministack."
  type        = list(string)
  default     = []
}

variable "alb_security_group_ids" {
  description = "Security groups for the ALB. Empty for Ministack."
  type        = list(string)
  default     = []
}

# ── ALB ────────────────────────────────────────────────────────────────────────

variable "create_alb" {
  description = <<-EOT
    Create an Application Load Balancer fronting the service.
    Set false for Ministack (ALB requires VPC subnets for placement).
    In real AWS: always true for internet-facing services.
  EOT
  type    = bool
  default = true
}

variable "health_check_path" {
  description = "HTTP path the ALB uses for health checks."
  type        = string
  default     = "/"
}

# ── IAM wiring ─────────────────────────────────────────────────────────────────

variable "permission_boundary_arn" {
  description = <<-EOT
    ARN of the IAM permission boundary to apply to all roles in this module.
    Wire from dependency.iam.outputs.permission_boundary_arn in real AWS.
    Ministack: set to empty string — PutRolePermissionsBoundary not supported.
  EOT
  type    = string
  default = ""
}

variable "sqs_queue_arns" {
  description = <<-EOT
    SQS queue ARNs the task role can send/receive on.
    Wires SQS module outputs into ECS task permissions.
    Empty list = no SQS policy statement added.
  EOT
  type    = list(string)
  default = []
}

variable "rds_secret_arns" {
  description = <<-EOT
    Secrets Manager secret ARNs the task role can read.
    Wires RDS module outputs into ECS task permissions.
    Empty list = no Secrets Manager policy statement added.
    Accepts prefix ARNs with wildcard: arn:aws:...:secret:project/env/rds/*
  EOT
  type    = list(string)
  default = []
}
