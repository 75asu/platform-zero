variable "name" {
  description = "Name prefix for all VPC resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project name used in tags"
  type        = string
  default     = "platform-zero"
}

variable "cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "List of availability zones to deploy subnets into"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnets" {
  description = "CIDRs for public subnets (one per AZ). ALB and NAT gateway tier."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "CIDRs for private subnets (one per AZ). ECS tasks and EC2 app tier."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "data_subnets" {
  description = "CIDRs for data subnets (one per AZ). RDS and ElastiCache tier — no route to internet."
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "enable_nat_gateway" {
  description = "Create a NAT gateway so private subnets can reach the internet. Set false for Ministack (not supported)."
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway instead of one per AZ. Saves cost in dev; use false in prod."
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC (required for RDS endpoint resolution)"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs to CloudWatch. Requires cloudwatch_log_group_name."
  type        = bool
  default     = false
}

variable "cloudwatch_log_group_name" {
  description = "CloudWatch log group for VPC flow logs. Only used when enable_flow_logs = true."
  type        = string
  default     = ""
}

variable "flow_logs_traffic_type" {
  description = "VPC flow log traffic type: ALL, ACCEPT, or REJECT"
  type        = string
  default     = "ALL"
  validation {
    condition     = contains(["ALL", "ACCEPT", "REJECT"], var.flow_logs_traffic_type)
    error_message = "flow_logs_traffic_type must be ALL, ACCEPT, or REJECT"
  }
}
