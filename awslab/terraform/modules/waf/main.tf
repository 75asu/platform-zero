locals {
  name = "${var.project}-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }

  # Convenience locals for dynamic block conditions
  ip_block_list         = var.ip_block_list_key != "" ? [1] : []
  ip_allow_list         = var.ip_allow_list_key != "" ? [1] : []
  blocked_countries_list = length(var.blocked_countries) > 0 ? [1] : []
}

# ── IP sets ────────────────────────────────────────────────────────────────────
# Named collections of IP addresses for use in rules.
# Use cases: office IP whitelist, known-bad IP blocklist, bot IPs.
resource "aws_wafv2_ip_set" "this" {
  for_each = var.ip_sets

  name               = "${local.name}-${each.key}"
  scope              = var.scope
  ip_address_version = each.value.ip_address_version
  addresses          = each.value.addresses

  tags = merge(local.common_tags, {
    Name = "${local.name}-${each.key}"
  })
}

# ── Custom rule groups ─────────────────────────────────────────────────────────
# Reusable collections of rules — share across multiple web ACLs.
# Real AWS: split common rules into shared rule groups, reference via ARN.
resource "aws_wafv2_rule_group" "this" {
  for_each = var.rule_groups

  name     = "${local.name}-${each.key}"
  scope    = var.scope
  capacity = each.value.capacity

  dynamic "rule" {
    for_each = each.value.rules
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        dynamic "allow" {
          for_each = rule.value.action == "allow" ? [1] : []
          content {}
        }
        dynamic "block" {
          for_each = rule.value.action == "block" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = rule.value.action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        # IP set reference
        dynamic "ip_set_reference_statement" {
          for_each = lookup(rule.value, "ip_set_key", null) != null ? [1] : []
          content {
            arn = aws_wafv2_ip_set.this[rule.value.ip_set_key].arn
          }
        }

        # Geo match
        dynamic "geo_match_statement" {
          for_each = lookup(rule.value, "country_codes", null) != null ? [1] : []
          content {
            country_codes = rule.value.country_codes
          }
        }

        # Rate-based (DDoS/brute force protection)
        dynamic "rate_based_statement" {
          for_each = lookup(rule.value, "rate_limit", null) != null ? [1] : []
          content {
            limit              = rule.value.rate_limit
            aggregate_key_type = lookup(rule.value, "rate_aggregate_key", "IP")
          }
        }

        # Byte match (string/regex in request)
        dynamic "byte_match_statement" {
          for_each = lookup(rule.value, "byte_match", null) != null ? [1] : []
          content {
            positional_constraint = rule.value.byte_match.positional_constraint
            search_string         = rule.value.byte_match.search_string
            field_to_match {
              dynamic "single_header" {
                for_each = rule.value.byte_match.field_type == "single_header" ? [1] : []
                content {
                  name = lookup(rule.value.byte_match, "field_data", "")
                }
              }
              dynamic "uri_path" {
                for_each = rule.value.byte_match.field_type == "uri_path" ? [1] : []
                content {}
              }
              dynamic "query_string" {
                for_each = rule.value.byte_match.field_type == "query_string" ? [1] : []
                content {}
              }
              dynamic "body" {
                for_each = rule.value.byte_match.field_type == "body" ? [1] : []
                content {}
              }
              dynamic "method" {
                for_each = rule.value.byte_match.field_type == "method" ? [1] : []
                content {}
              }
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }

      # CloudWatch metrics per rule
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name}-${each.key}-${rule.key}"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name}-${each.key}"
    sampled_requests_enabled   = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-${each.key}"
  })
}

# ── Web ACL ────────────────────────────────────────────────────────────────────
# The main WAF resource. Attaches to ALB, CloudFront, or API Gateway.
# Default action: allow (for monitoring mode) or block (for enforcement).
# Real production: start with count mode, observe, then switch to block.
resource "aws_wafv2_web_acl" "this" {
  name        = local.name
  description = "WAF ${local.name} — managed by Terraform"
  scope       = var.scope

  default_action {
    dynamic "allow" {
      for_each = var.default_action == "allow" ? [1] : []
      content {}
    }
    dynamic "block" {
      for_each = var.default_action == "block" ? [1] : []
      content {}
    }
  }

  # ── AWS Managed Rules ──────────────────────────────────────────────────────
  # Free rule groups maintained by AWS. Baseline protection.
  # CoreRuleSet: OWASP Top 10, SQL injection, XSS, LFI, command injection.
  # AdminProtection: blocks access to admin paths from external IPs.
  # KnownBadInputs: blocks known-malicious request patterns.
  # Rate limit: IP-based throttling for brute force / DDoS.
  dynamic "rule" {
    for_each = var.enable_managed_core_rule_set ? [1] : []
    content {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 0

      override_action {
        count {}
      }
      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesCommonRuleSet"
          vendor_name = "AWS"
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "AWSManagedRulesCommonRuleSet"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.enable_managed_admin_protection ? [1] : []
    content {
      name     = "AWSManagedRulesAdminProtection"
      priority = 1

      override_action {
        count {}
      }
      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesAdminProtection"
          vendor_name = "AWS"
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "AWSManagedRulesAdminProtection"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.enable_managed_known_bad_inputs ? [1] : []
    content {
      name     = "AWSManagedRulesKnownBadInputs"
      priority = 2

      override_action {
        count {}
      }
      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesKnownBadInputsRuleSet"
          vendor_name = "AWS"
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "AWSManagedRulesKnownBadInputs"
        sampled_requests_enabled   = true
      }
    }
  }

  # ── Rate-based rule ────────────────────────────────────────────────────────
  # IP-based rate limiting. Blocks IPs exceeding the threshold in a 5-min window.
  # Use for DDoS protection, brute force login, API abuse.
  dynamic "rule" {
    for_each = var.rate_limit > 0 ? [1] : []
    content {
      name     = "RateLimit"
      priority = 3

      action {
        block {}
      }
      statement {
        rate_based_statement {
          limit              = var.rate_limit
          aggregate_key_type = "IP"
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "RateLimit"
        sampled_requests_enabled   = true
      }
    }
  }

  # ── IP block list ──────────────────────────────────────────────────────────
  dynamic "rule" {
    for_each = length(local.ip_block_list) > 0 ? [1] : []
    content {
      name     = "IPBlockList"
      priority = 10

      action {
        block {}
      }
      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.this[var.ip_block_list_key].arn
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "IPBlockList"
        sampled_requests_enabled   = true
      }
    }
  }

  # ── IP allow list ──────────────────────────────────────────────────────────
  dynamic "rule" {
    for_each = length(local.ip_allow_list) > 0 ? [1] : []
    content {
      name     = "IPAllowList"
      priority = 20

      action {
        allow {}
      }
      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.this[var.ip_allow_list_key].arn
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "IPAllowList"
        sampled_requests_enabled   = true
      }
    }
  }

  # ── Geo blocking ───────────────────────────────────────────────────────────
  dynamic "rule" {
    for_each = length(local.blocked_countries_list) > 0 ? [1] : []
    content {
      name     = "GeoBlock"
      priority = 30

      action {
        block {}
      }
      statement {
        geo_match_statement {
          country_codes = var.blocked_countries
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "GeoBlock"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = local.name
    sampled_requests_enabled   = true
  }

  tags = merge(local.common_tags, {
    Name = local.name
  })
}

# ── Association ───────────────────────────────────────────────────────────────
# Attach the web ACL to an ALB or other supported resource.
# Ministack: association may not fully enforce, but the resource is created.
resource "aws_wafv2_web_acl_association" "this" {
  count = var.alb_arn != null ? 1 : 0

  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

# ── Logging ───────────────────────────────────────────────────────────────────
# Sends WAF decision logs to CloudWatch Logs or S3.
# Real AWS: mandatory for audit and debugging — every allow/block is logged.
# Ministack: logging may not be supported, gated by enable_logging.
resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = var.enable_logging ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.this.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]

  depends_on = [aws_cloudwatch_log_group.waf]
}

resource "aws_cloudwatch_log_group" "waf" {
  count = var.enable_logging ? 1 : 0

  name              = "aws-waf-logs-${local.name}"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "aws-waf-logs-${local.name}"
  })
}
