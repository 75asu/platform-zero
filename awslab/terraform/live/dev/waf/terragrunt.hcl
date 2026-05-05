include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/waf"
}

inputs = {
  environment = "dev"

  # Start in monitoring mode (allow) — safe to deploy first.
  # Switch to block after observing in CloudWatch.
  default_action = "allow"

  # AWS Managed Rules — baseline protection, free with WAF.
  enable_managed_core_rule_set  = true
  enable_managed_admin_protection = true
  enable_managed_known_bad_inputs = true

  # Rate limiting — disabled for lab, enable for prod.
  rate_limit = 0

  # IP sets — empty for lab, add office IPs in prod.
  ip_sets            = {}
  ip_block_list_key  = ""
  ip_allow_list_key  = ""

  blocked_countries = []

  # Custom rule groups — none for dev baseline.
  rule_groups = {}

  # No ALB yet — wire ECS ALB ARN here when built.
  alb_arn = null

  # Ministack: WAF logging not supported.
  enable_logging = false
}
