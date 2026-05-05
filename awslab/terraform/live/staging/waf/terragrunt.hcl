include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/waf"
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

  alb_arn = null

  enable_logging = false
}
