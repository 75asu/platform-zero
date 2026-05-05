locals {
  name = "${var.project}-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }

  # Origin IDs — computed once, referenced throughout
  s3_origin_id  = "s3-${var.s3_origin_bucket != null ? var.s3_origin_bucket : "none"}"
  alb_origin_id = "alb-${var.alb_origin_dns != null ? "platform-zero" : "none"}"

  # Primary origin: ALB if configured, otherwise S3
  primary_origin_id = var.alb_origin_dns != null ? local.alb_origin_id : local.s3_origin_id
}

# ── Origin Access Control (OAC) ───────────────────────────────────────────────
# Secure S3 origin — CloudFront signs requests, S3 bucket policy validates.
# Replaces OAI (legacy). OAC supports all regions, all HTTP methods, and SSE-KMS.
# Required for S3 origins in production. Without OAC, S3 must be public or
# use CloudFront OAI.
resource "aws_cloudfront_origin_access_control" "s3" {
  count = var.s3_origin_bucket != null ? 1 : 0

  name                              = "${local.name}-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ── S3 bucket policy for OAC ──────────────────────────────────────────────────
# Allows CloudFront OAC to read objects from the S3 origin bucket.
# Without this policy, CloudFront cannot access the bucket.
# Only attached when S3 origin is configured with OAC.
resource "aws_s3_bucket_policy" "cf_oac" {
  count = var.s3_origin_bucket != null ? 1 : 0

  bucket = var.s3_origin_bucket
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontOAC"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${var.s3_origin_bucket_arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.this.arn
        }
      }
    }]
  })
}

# ── Distribution ──────────────────────────────────────────────────────────────
resource "aws_cloudfront_distribution" "this" {
  comment = "${local.name} — managed by Terraform"
  enabled = var.enabled

  # Price class: which edge locations to use.
  # PriceClass_100: US + Europe + Israel (cheapest)
  # PriceClass_200: adds South America, Asia, Australia
  # PriceClass_All: all edge locations (most expensive, lowest latency globally)
  price_class = var.price_class

  # HTTP versions — always enable HTTP/2 and HTTP/3 for performance.
  http_version    = "http2and3"
  is_ipv6_enabled = true

  # ── Default cache behaviour ───────────────────────────────────────────────
  # The catch-all behaviour — applies when no path pattern matches.
  default_cache_behavior {
    target_origin_id = local.primary_origin_id

    # Always redirect HTTP → HTTPS. Mandatory for security.
    viewer_protocol_policy = var.viewer_protocol_policy

    # Allowed HTTP methods: GET_HEAD (static), GET_HEAD_OPTIONS, or ALL
    allowed_methods  = var.default_allowed_methods
    cached_methods   = var.default_cached_methods
    compress         = var.enable_compression

    # Cache policy — which headers/cookies/query strings to forward
    # Managed-CachingOptimized: caches based on the full URL (query string stripped)
    # Managed-CachingDisabled: forwards everything, no caching
    cache_policy_id = var.default_cache_policy_id

    # Origin request policy — what to include in requests to origin
    # Managed-AllViewer: includes everything from the viewer (good for dynamic)
    # Managed-UserAgentRefererHeaders: only User-Agent and Referer
    origin_request_policy_id = var.default_origin_request_policy_id

    # Response headers policy — security headers injected by CloudFront
    # Managed-SecurityHeadersPolicy: HSTS, XSS, content-type, etc.
    response_headers_policy_id = var.response_headers_policy_id

    # Restrict viewer access — signed URLs/Cookies for private content
    trusted_key_groups = []
    trusted_signers    = []
  }

  # ── Origins ────────────────────────────────────────────────────────────────
  # S3 origin with OAC
  dynamic "origin" {
    for_each = var.s3_origin_bucket != null ? [1] : []
    content {
      domain_name = var.s3_origin_domain
      origin_id   = local.s3_origin_id

      origin_access_control_id = aws_cloudfront_origin_access_control.s3[0].id

      # S3 origins: always TLS, no custom headers needed
      connection_attempts = 3
      connection_timeout  = 10
    }
  }

  # ALB origin
  dynamic "origin" {
    for_each = var.alb_origin_dns != null ? [1] : []
    content {
      domain_name = var.alb_origin_dns
      origin_id   = local.alb_origin_id

      custom_origin_config {
        http_port                = 80
        https_port               = 443
        origin_protocol_policy   = "https-only"
        origin_ssl_protocols     = ["TLSv1.2"]
        origin_keepalive_timeout = 60
        origin_read_timeout      = 30
      }
    }
  }

  # ── Ordered cache behaviours ───────────────────────────────────────────────
  # Path-pattern-based rules for specific URL prefixes.
  # Processed in priority order — first match wins.
  dynamic "ordered_cache_behavior" {
    for_each = var.ordered_cache_behaviors
    content {
      path_pattern           = ordered_cache_behavior.value.path_pattern
      target_origin_id       = ordered_cache_behavior.value.origin_id
      viewer_protocol_policy = ordered_cache_behavior.value.viewer_protocol_policy
      allowed_methods        = ordered_cache_behavior.value.allowed_methods
      cached_methods         = ordered_cache_behavior.value.cached_methods
      compress               = ordered_cache_behavior.value.compress

      cache_policy_id          = ordered_cache_behavior.value.cache_policy_id
      origin_request_policy_id = ordered_cache_behavior.value.origin_request_policy_id

      response_headers_policy_id = lookup(
        ordered_cache_behavior.value, "response_headers_policy_id", ""
      )

      dynamic "lambda_function_association" {
        for_each = ordered_cache_behavior.value.lambda_association_arn != "" ? [1] : []
        content {
          event_type   = "viewer-request"
          lambda_arn   = ordered_cache_behavior.value.lambda_association_arn
          include_body = ordered_cache_behavior.value.include_body
        }
      }
    }
  }

  # ── Geo restrictions ───────────────────────────────────────────────────────
  # Block or allow by country. Complement to WAF geo blocking.
  # WAF: more granular (rate limits, IP sets, managed rules).
  # Geo restriction: simple, no WCU cost, at the CDN level.
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  # ── Custom error responses ─────────────────────────────────────────────────
  # Serve a custom error page from S3 on 403/404/500.
  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      error_code         = custom_error_response.value.error_code
      response_code      = custom_error_response.value.response_code
      response_page_path = custom_error_response.value.response_page_path
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  # ── Logging ────────────────────────────────────────────────────────────────
  # Standard logs (every request) and real-time logs (Kinesis Data Streams).
  # Standard logs go to S3 — cheaper, used for analytics.
  # Real-time logs go to Kinesis — immediate, used for monitoring.
  dynamic "logging_config" {
    for_each = var.logging_bucket != null ? [1] : []
    content {
      bucket          = var.logging_bucket
      include_cookies = var.logging_include_cookies
      prefix          = var.logging_prefix
    }
  }

  # ── Default root object ────────────────────────────────────────────────────
  # File served when viewer requests the root path (/).
  # Typically index.html for SPA, but set to empty for ALB origins.
  default_root_object = var.default_root_object

  # ── WAF association ────────────────────────────────────────────────────────
  # Attach WAF v2 web ACL to this distribution.
  # Requires scope = CLOUDFRONT on the web ACL.
  web_acl_id = var.waf_web_acl_arn

  # ── Viewer certificate ─────────────────────────────────────────────────────
  # Default CloudFront certificate (*.cloudfront.net) — free, no setup.
  # ACM certificate: custom domain with DNS validation.
  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == null
    acm_certificate_arn            = var.acm_certificate_arn
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = var.acm_certificate_arn != null ? "sni-only" : null
  }

  tags = merge(local.common_tags, {
    Name = local.name
  })
}

# ── Origin access identity (OAI) — legacy, not created by default ─────────────
# OAC is preferred. OAI is kept for backward compatibility.
# Switch to OAI only if OAC is not supported by your use case.
# resource "aws_cloudfront_origin_access_identity" "legacy" { ... }
