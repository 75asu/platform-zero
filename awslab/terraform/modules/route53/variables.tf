variable "zone_name" {
  description = "Domain name for the hosted zone (e.g., binarysquad.org)"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project tag applied to all resources"
  type        = string
  default     = "platform-zero"
}

variable "force_destroy" {
  description = <<-EOT
    Delete all records when destroying the zone. Safe for labs/dev.
    Real AWS: set false — requires manual record cleanup before zone deletion
    to prevent accidental DNS outages.
  EOT
  type    = bool
  default = true
}

# ── Query logging ─────────────────────────────────────────────────────────────

variable "enable_query_logging" {
  description = "Log every DNS query to CloudWatch Logs for audit and debugging"
  type        = bool
  default     = true
}

variable "query_log_retention_days" {
  description = "Retention period for Route53 query logs in CloudWatch"
  type        = number
  default     = 30

  validation {
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.query_log_retention_days)
    error_message = "query_log_retention_days must be a valid CloudWatch retention period"
  }
}

# ── Records ───────────────────────────────────────────────────────────────────

variable "records" {
  description = <<-EOT
    Map of DNS records to create. Each entry defines one record.

    Example:
    {
      www = {
        name   = "www"
        type   = "CNAME"
        ttl    = 300
        values = ["my-alb.elb.amazonaws.com"]
      }
      api = {
        name   = "api"
        type   = "A"
        alias_target = {
          dns_name              = "dualstack.my-alb.elb.amazonaws.com"
          hosted_zone_id        = "Z35SXDOTRQ7X7K"
          evaluate_target_health = true
        }
      }
    }

    Supported types: A, CNAME
    For alias records: set type="A" + alias_target block
    For health checks: add health_check_id = aws_route53_health_check.this["key"].id
    For multi-value routing: add multivalue = true (returns up to 8 healthy IPs per query)
  EOT
  type = map(object({
    name              = string
    type              = string
    ttl               = optional(number)
    values            = optional(list(string))
    alias_target = optional(object({
      dns_name               = string
      hosted_zone_id         = string
      evaluate_target_health = optional(bool)
    }))
    health_check_id = optional(string)
    multivalue      = optional(bool)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.records : contains(["A", "CNAME"], v.type)
    ])
    error_message = "Each record type must be A or CNAME. For alias records, use type=\"A\" with alias_target."
  }
}

variable "default_ttl" {
  description = <<-EOT
    Default TTL in seconds for records that don't specify one.
    Lower = faster DNS propagation during failover, more queries to Route53.
    Higher = fewer queries, slower propagation.
    300 = 5 minutes (good balance for most internal services).
    60 = 1 minute (use for failover records that need fast switches).
    86400 = 24 hours (use for static records like MX/TXT).
  EOT
  type    = number
  default = 300
}

# ── Health checks ─────────────────────────────────────────────────────────────

variable "health_checks" {
  description = <<-EOT
    Map of Route53 health checks. Each check probes an endpoint from
    multiple global regions.

    Example:
    {
      app = {
        fqdn              = "app.binarysquad.org"
        port              = 443
        type              = "HTTPS"
        resource_path     = "/health"
        failure_threshold = 3
        request_interval  = 30
      }
    }

    fqdn: DNS name to check (Route53 resolves it first)
    ip_address: IP to check directly (skip DNS resolution)
    port: TCP port to connect to
    type: HTTP | HTTPS | TCP | HTTPS_STR_MATCH | HTTP_STR_MATCH
    resource_path: path for HTTP/HTTPS checks (e.g., /health)
    search_string: substring to match in response body (STR_MATCH types only)
    failure_threshold: number of consecutive failures before marking unhealthy (default 3)
    request_interval: seconds between probes — 10 or 30 (lower = faster detection, higher cost)
    measure_latency: also measure response time (for latency-based routing)
    regions: subset of regions to probe from (null = all regions)

    Note: Route53 health checks are per-endpoint. For ALB-backed services,
    prefer ALB target group health checks — they're free and more granular
    (per-task vs per-DNS-endpoint). Route53 health checks are for:
    - Non-AWS endpoints (on-prem, third-party APIs)
    - Failover between ALBs in different regions
    - Failover between AWS and on-prem endpoints
  EOT
  type = map(object({
    fqdn              = optional(string)
    ip_address        = optional(string)
    port              = number
    type              = string
    resource_path     = optional(string)
    search_string     = optional(string)
    failure_threshold = optional(number)
    request_interval  = optional(number)
    measure_latency   = optional(bool)
    invert_healthcheck = optional(bool)
    regions           = optional(list(string))
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.health_checks : contains(
        ["HTTP", "HTTPS", "TCP", "HTTP_STR_MATCH", "HTTPS_STR_MATCH"],
        v.type
      )
    ])
    error_message = "Health check type must be HTTP, HTTPS, TCP, HTTP_STR_MATCH, or HTTPS_STR_MATCH"
  }
}
