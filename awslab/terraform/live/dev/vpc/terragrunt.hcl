include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/vpc"
}

inputs = {
  name        = "platform-zero-dev"
  environment = "dev"

  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]
  data_subnets    = ["10.0.21.0/24", "10.0.22.0/24"]

  # Ministack: NAT gateways are not supported.
  # In real AWS: enable_nat_gateway = true, single_nat_gateway = true (dev) / false (prod)
  enable_nat_gateway = false
  single_nat_gateway = true

  # Flow logs: disabled in lab (Floci does support CloudWatch Logs but not flow log delivery).
  # In real AWS: enable_flow_logs = true, cloudwatch_log_group_name = "/aws/vpc/platform-zero-dev"
  enable_flow_logs = false

  # Floci doesn't auto-create a default SG when creating a VPC.
  # In real AWS: remove this line (default = true) to lock down the default SG.
  lockdown_default_sg = false
}
