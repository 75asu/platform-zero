# Excluded from `terragrunt run --all` — CloudFront not supported by Floci.
# Apply manually if needed. In real AWS: remove this exclude block.
exclude {
  if      = true
  actions = ["all"]
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/cloudfront"
}

inputs = {
  environment = "dev"

  # Distribution config
  enabled     = true
  price_class = "PriceClass_100"
  viewer_protocol_policy = "redirect-to-https"

  # Default cache behaviour — use AWS managed policies
  default_allowed_methods  = ["GET", "HEAD"]
  default_cached_methods   = ["GET", "HEAD"]
  enable_compression       = true
  default_cache_policy_id  = "658327ea-f89d-4fab-a63d-7e88639e58f6"  # CachingOptimized
  default_origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"  # AllViewer
  response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03"  # SecurityHeaders

  # Origins — S3 only for Ministack (no ALB yet)
  s3_origin_bucket     = "platform-zero-dev-app-data"
  s3_origin_bucket_arn = "arn:aws:s3:::platform-zero-dev-app-data"
  s3_origin_domain     = "platform-zero-dev-app-data.s3.us-east-1.amazonaws.com"
  alb_origin_dns       = null

  # WAF — wire when WAF module has CLOUDFRONT scope
  waf_web_acl_arn = null

  # Geo — no restrictions in dev
  geo_restriction_type     = "none"
  geo_restriction_locations = []

  # Error pages — none for now
  custom_error_responses = []

  ordered_cache_behaviors = []

  # Cert — default CloudFront cert (*.cloudfront.net)
  acm_certificate_arn = null

  default_root_object = ""

  # Logging — disabled for Ministack
  logging_bucket          = null
  logging_include_cookies = false
  logging_prefix          = "cloudfront-logs/"
}
