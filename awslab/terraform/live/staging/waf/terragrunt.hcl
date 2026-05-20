# Excluded from `terragrunt run --all` — WAFv2 not supported by Floci.
# Apply manually if needed. In real AWS: remove this exclude block.
exclude {
  if      = true
  actions = ["all"]
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/waf"
}

dependency "alb" {
  config_path = "../alb"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    alb_arn = "arn:aws:elasticloadbalancing:us-east-1:000000000002:loadbalancer/app/mock/0000000000000000"
  }
}

inputs = {
  environment = "staging"

  # Staging runs in block mode — closer to prod behaviour.
  default_action = "block"

  enable_managed_core_rule_set  = true
  enable_managed_admin_protection = true
  enable_managed_known_bad_inputs = true

  # Rate limiting enabled in staging — tests enforcement before prod.
  rate_limit = 2000

  ip_sets            = {}
  ip_block_list_key  = ""
  ip_allow_list_key  = ""

  blocked_countries = []

  rule_groups = {}

  alb_arn = dependency.alb.outputs.alb_arn

  enable_logging = false
}
