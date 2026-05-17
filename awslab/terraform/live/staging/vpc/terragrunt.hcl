include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/vpc"
}

inputs = {
  name        = "platform-zero-staging"
  environment = "staging"

  # Staging uses 10.1.0.0/16 — isolated from dev (10.0.0.0/16).
  cidr = "10.1.0.0/16"
  azs  = ["us-east-1a", "us-east-1b"]

  public_subnets  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnets = ["10.1.11.0/24", "10.1.12.0/24"]
  data_subnets    = ["10.1.21.0/24", "10.1.22.0/24"]

  # Ministack: NAT gateway not supported.
  # In real AWS: enable_nat_gateway = true for staging (private subnet egress).
  enable_nat_gateway = false
  single_nat_gateway = true

  # Flow logs disabled for Ministack (no real CloudWatch billing concern).
  # In real AWS: enable for staging to catch anomalous traffic patterns.
  enable_flow_logs = false
}
