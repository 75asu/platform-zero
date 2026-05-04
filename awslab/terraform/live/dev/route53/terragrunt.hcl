include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/route53"
}

inputs = {
  environment = "dev"
  zone_name   = "dev.binarysquad.org"

  # Ministack: force_destroy = true — safe for lab teardown
  # Real AWS: set false to prevent accidental DNS outages
  force_destroy = true

  # Query logging: Ministack does not support Route53 query logging.
  # Real AWS: set true to audit every DNS lookup to CloudWatch/S3.
  enable_query_logging    = false
  query_log_retention_days = 30

  # Records — local lab defaults.
  # Real AWS: add ALB alias records pointing at ECS ALB outputs.
  records = {
    app = {
      name = "app"
      type = "CNAME"
      ttl  = 300
      # Placeholder — replace with actual ECS ALB DNS when wired
      values = ["placeholder.local"]
    }
  }

  # Health checks — wire to ECS service endpoints once ALB is deployed.
  health_checks = {}
}
