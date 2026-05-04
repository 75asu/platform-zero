include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/route53"
}

inputs = {
  environment = "staging"
  zone_name   = "staging.binarysquad.org"

  force_destroy = true

  enable_query_logging    = false   # Ministack doesn't support Route53 query logging
  query_log_retention_days = 30

  # Staging mirrors dev — separate zone for multi-env isolation.
  # Real AWS: each environment gets its own hosted zone in its own account.
  records = {
    app = {
      name = "app"
      type = "CNAME"
      ttl  = 300
      # Placeholder — replace with actual ECS ALB DNS when wired
      values = ["placeholder.local"]
    }
  }

  health_checks = {}
}
