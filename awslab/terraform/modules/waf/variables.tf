variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "project" {
  description = "Project tag"
  type        = string
  default     = "platform-zero"
}

# ── Scope ─────────────────────────────────────────────────────────────────────

variable "scope" {
  description = <<-EOT
    REGIONAL: for ALB, API Gateway, AppSync. WAF runs in the AWS region.
    CLOUDFRONT: for CloudFront distributions. WAF runs at edge locations globally.
    Ministack: use REGIONAL.
  EOT
  type    = string
  default = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "scope must be REGIONAL or CLOUDFRONT"
  }
}

variable "default_action" {
  description = <<-EOT
    Default action for requests that match no rules:
    - "allow": monitoring mode — log everything, block nothing (safe to deploy first)
    - "block": enforcement mode — block anything not explicitly allowed
    Start with allow, observe in CloudWatch, then switch to block.
  EOT
  type    = string
  default = "allow"

  validation {
    condition     = contains(["allow", "block"], var.default_action)
    error_message = "default_action must be allow or block"
  }
}

# ── AWS Managed Rules ─────────────────────────────────────────────────────────

variable "enable_managed_core_rule_set" {
  description = "Enable AWS Managed Core Rule Set — OWASP Top 10, SQL injection, XSS, LFI"
  type        = bool
  default     = true
}

variable "enable_managed_admin_protection" {
  description = "Enable AWS Managed Admin Protection — blocks external access to admin paths"
  type        = bool
  default     = true
}

variable "enable_managed_known_bad_inputs" {
  description = "Enable AWS Managed Known Bad Inputs — blocks known-malicious patterns"
  type        = bool
  default     = true
}

# ── Rate limiting ─────────────────────────────────────────────────────────────

variable "rate_limit" {
  description = <<-EOT
    Maximum requests per 5-minute window from a single IP before blocking.
    Set to 0 to disable rate limiting.
    Recommended: 2000 for public APIs, 100 for login endpoints.
    Ministack: rule is created but not enforced (no real traffic).
  EOT
  type    = number
  default = 0
}

# ── IP sets ───────────────────────────────────────────────────────────────────

variable "ip_sets" {
  description = <<-EOT
    Named IP address collections for use in rules.
    Example:
    {
      office = {
        ip_address_version = "IPV4"
        addresses          = ["203.0.113.0/24"]
      }
    }
  EOT
  type = map(object({
    ip_address_version = string
    addresses          = list(string)
  }))
  default = {}
}

variable "ip_block_list_key" {
  description = "Key in ip_sets map for the block list. Empty string disables IP blocking."
  type        = string
  default     = ""
}

variable "ip_allow_list_key" {
  description = "Key in ip_sets map for the allow list. Empty string disables IP whitelisting."
  type        = string
  default     = ""
}

# ── Geo blocking ──────────────────────────────────────────────────────────────

variable "blocked_countries" {
  description = <<-EOT
    ISO 3166-1 alpha-2 country codes to block (e.g., ["KP", "IR"]).
    Empty list disables geo blocking.
    Ministack: rule is created but not enforced.
  EOT
  type    = list(string)
  default = []
}

# ── Custom rule groups ────────────────────────────────────────────────────────

variable "rule_groups" {
  description = <<-EOT
    Custom reusable rule groups. Share across multiple web ACLs.
    Each rule group has a capacity (WCU) and a list of rules.

    Example:
    {
      sql-injection = {
        capacity = 30
        rules = [
          {
            name     = "BlockSQLiURI"
            priority = 0
            action   = "block"
            byte_match = {
              positional_constraint = "CONTAINS"
              search_string         = "SELECT"
              field_type            = "URI_PATH"
            }
          }
        ]
      }
    }

    Supported rule actions: allow, block, count
    Supported statement types:
      - ip_set_key: reference an IP set by key
      - country_codes: geo match
      - rate_limit: rate-based (with optional aggregate_key)
      - byte_match: string/regex match
  EOT
  type = map(object({
    capacity = number
    rules = list(object({
      name     = string
      priority = number
      action   = string
      ip_set_key       = optional(string)
      country_codes    = optional(list(string))
      rate_limit       = optional(number)
      rate_aggregate_key = optional(string)
      byte_match = optional(object({
        positional_constraint = string
        search_string         = string
        field_type            = string
        field_data            = optional(string)
      }))
    }))
  }))
  default = {}
}

# ── ALB association ───────────────────────────────────────────────────────────

variable "alb_arn" {
  description = "ALB ARN to associate this WAF web ACL with. Null = no association."
  type        = string
  default     = null
}

# ── Logging ───────────────────────────────────────────────────────────────────

variable "enable_logging" {
  description = <<-EOT
    Send WAF decision logs to CloudWatch. Every allow/block is logged.
    Ministack: set false — WAF logging may not be supported.
    Real AWS: set true — mandatory for audit.
  EOT
  type    = bool
  default = false
}

variable "log_retention_days" {
  description = "Retention period for WAF logs in CloudWatch"
  type        = number
  default     = 30
}
