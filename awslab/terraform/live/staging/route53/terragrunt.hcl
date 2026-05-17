include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/route53"
}

dependency "alb" {
  config_path = "../alb"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    alb_dns_name       = "mock-alb.us-east-1.elb.amazonaws.com"
    alb_hosted_zone_id = "Z35SXDOTRQ7X7K"
  }
}

inputs = {
  environment = "staging"
  zone_name   = "staging.binarysquad.org"

  force_destroy = true

  enable_query_logging     = false
  query_log_retention_days = 30

  records = {
    app = {
      name = "app"
      type = "CNAME"
      ttl  = 300
      values = [dependency.alb.outputs.alb_dns_name]
    }
  }

  health_checks = {}
}
