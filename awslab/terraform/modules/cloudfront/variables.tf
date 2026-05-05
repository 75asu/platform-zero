variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project tag"
  type        = string
  default     = "platform-zero"
}

# ── Distribution config ───────────────────────────────────────────────────────

variable "enabled" {
  description = "Enable (true) or disable (false) the distribution"
  type        = bool
  default     = true
}

variable "price_class" {
  description = <<-EOT
    Edge location coverage:
    PriceClass_100: US + Canada + Europe + Israel (cheapest)
    PriceClass_200: adds South America, Asia, Australia
    PriceClass_All: all edge locations (lowest global latency, most expensive)
  EOT
  type    = string
  default = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be PriceClass_100, PriceClass_200, or PriceClass_All"
  }
}

variable "default_root_object" {
  description = "File served at root (/). E.g., index.html for SPA. Empty for ALB origins."
  type        = string
  default     = ""
}

# ── Viewer protocol ───────────────────────────────────────────────────────────

variable "viewer_protocol_policy" {
  description = <<-EOT
    How CloudFront handles HTTP vs HTTPS from viewers:
    - redirect-to-https: HTTP → 301 redirect to HTTPS (recommended)
    - https-only: drop HTTP connections (faster, no redirect)
    - allow-all: accept both (insecure, never use in production)
  EOT
  type    = string
  default = "redirect-to-https"

  validation {
    condition     = contains(["redirect-to-https", "https-only", "allow-all"], var.viewer_protocol_policy)
    error_message = "viewer_protocol_policy must be redirect-to-https, https-only, or allow-all"
  }
}

# ── Cache behaviour defaults ──────────────────────────────────────────────────

variable "default_allowed_methods" {
  description = "HTTP methods allowed on the default cache behaviour: GET_HEAD, GET_HEAD_OPTIONS, or ALL"
  type        = list(string)
  default     = ["GET", "HEAD"]
}

variable "default_cached_methods" {
  description = "HTTP methods that CloudFront caches responses for"
  type        = list(string)
  default     = ["GET", "HEAD"]
}

variable "enable_compression" {
  description = "Automatically compress objects before serving (gzip/brotli)"
  type        = bool
  default     = true
}

variable "default_cache_policy_id" {
  description = "Cache policy for the default behaviour. Managed-CachingOptimized = 658327ea-f89d-4fab-a63d-7e88639e58f6"
  type        = string
  default     = "658327ea-f89d-4fab-a63d-7e88639e58f6"
}

variable "default_origin_request_policy_id" {
  description = "Origin request policy for default behaviour. Managed-AllViewer = 216adef6-5c7f-47e4-b989-5492eafa07d3"
  type        = string
  default     = "216adef6-5c7f-47e4-b989-5492eafa07d3"
}

variable "response_headers_policy_id" {
  description = "Response headers policy. Managed-SecurityHeadersPolicy = 67f7725c-6f97-4210-82d7-5512b31e9d03"
  type        = string
  default     = "67f7725c-6f97-4210-82d7-5512b31e9d03"
}

# ── Ordered cache behaviours ──────────────────────────────────────────────────

variable "ordered_cache_behaviors" {
  description = "Path-pattern-based cache behaviours for specific URL prefixes"
  type = list(object({
    path_pattern            = string
    origin_id               = string
    viewer_protocol_policy  = string
    allowed_methods         = list(string)
    cached_methods          = list(string)
    compress                = bool
    cache_policy_id         = string
    origin_request_policy_id = string
    response_headers_policy_id = string
    lambda_association_arn  = optional(string, "")
    include_body            = optional(bool, false)
  }))
  default = []
}

# ── Origins ───────────────────────────────────────────────────────────────────

variable "s3_origin_bucket" {
  description = "S3 bucket ID for the S3 origin. Set null to skip S3 origin."
  type        = string
  default     = null
}

variable "s3_origin_bucket_arn" {
  description = "S3 bucket ARN for the OAC bucket policy"
  type        = string
  default     = null
}

variable "s3_origin_domain" {
  description = "S3 bucket regional domain name for the origin (bucket.s3.region.amazonaws.com)"
  type        = string
  default     = null
}

variable "alb_origin_dns" {
  description = "ALB DNS name for the ALB origin. Set null to skip ALB origin."
  type        = string
  default     = null
}

# ── Geo restrictions ──────────────────────────────────────────────────────────

variable "geo_restriction_type" {
  description = "whitelist (allow only listed countries) or blacklist (block listed countries)"
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "whitelist", "blacklist"], var.geo_restriction_type)
    error_message = "geo_restriction_type must be none, whitelist, or blacklist"
  }
}

variable "geo_restriction_locations" {
  description = "ISO 3166-1 alpha-2 country codes. Only used when geo_restriction_type is not none."
  type        = list(string)
  default     = []
}

# ── Custom error responses ────────────────────────────────────────────────────

variable "custom_error_responses" {
  description = "Custom error pages served from S3 on specific HTTP error codes"
  type = list(object({
    error_code            = number
    response_code         = number
    response_page_path    = string
    error_caching_min_ttl = optional(number, 300)
  }))
  default = []
}

# ── Logging ───────────────────────────────────────────────────────────────────

variable "logging_bucket" {
  description = "S3 bucket for standard access logs. Null = no logging."
  type        = string
  default     = null
}

variable "logging_include_cookies" {
  description = "Include cookies in access logs"
  type        = bool
  default     = false
}

variable "logging_prefix" {
  description = "Key prefix for log objects in the logging bucket"
  type        = string
  default     = "cloudfront-logs/"
}

# ── WAF ───────────────────────────────────────────────────────────────────────

variable "waf_web_acl_arn" {
  description = "WAF web ACL ARN to attach. Must be CLOUDFRONT scope. Null = no WAF."
  type        = string
  default     = null
}

# ── TLS / Certificate ─────────────────────────────────────────────────────────

variable "acm_certificate_arn" {
  description = <<-EOT
    ACM certificate ARN for custom domain. Must be in us-east-1 for CloudFront.
    Null = use default CloudFront certificate (*.cloudfront.net).
  EOT
  type    = string
  default = null
}
