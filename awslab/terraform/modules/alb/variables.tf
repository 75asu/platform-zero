variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project tag applied to all resources"
  type        = string
  default     = "platform-zero"
}

variable "vpc_id" {
  description = "VPC ID — ALB and security groups are placed here"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB placement (one per AZ minimum)"
  type        = list(string)
}

variable "container_port" {
  description = "Port the ECS tasks listen on — ECS SG ingress and target group port"
  type        = number
  default     = 80
}

variable "internal" {
  description = "True = internal ALB (private subnets, VPC-only). False = internet-facing (public subnets)."
  type        = bool
  default     = false
}

variable "health_check_path" {
  description = "HTTP path the ALB health checker probes on each target"
  type        = string
  default     = "/"
}

variable "health_check_matcher" {
  description = "HTTP status codes considered healthy (e.g. '200' or '200-299')"
  type        = string
  default     = "200"
}

variable "health_check_interval" {
  description = "Seconds between ALB health checks per target"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Seconds ALB waits for a health check response before marking it failed"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Consecutive healthy checks before a target is marked healthy"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Consecutive failed checks before a target is marked unhealthy and drained"
  type        = number
  default     = 3
}

variable "deregistration_delay" {
  description = "Seconds ALB waits for in-flight requests to complete before deregistering a draining target"
  type        = number
  default     = 30
}

variable "stickiness_enabled" {
  description = "Enable ALB sticky sessions (lb_cookie). Required for stateful apps not using external session store."
  type        = bool
  default     = false
}

variable "stickiness_duration" {
  description = "Sticky session cookie duration in seconds"
  type        = number
  default     = 86400
}
