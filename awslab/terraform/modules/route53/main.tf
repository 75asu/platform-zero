locals {
  name = "${var.project}-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# ── Hosted zone ───────────────────────────────────────────────────────────────
# Public zone for Ministack (VPC not supported, so private zones aren't feasible).
# Real AWS: switch to private hosted zone + VPC associations for internal DNS,
# and use a separate public zone for internet-facing records.
resource "aws_route53_zone" "this" {
  name = var.zone_name

  comment = "${local.name} hosted zone — managed by Terraform"

  # Force destroy on teardown — safe for lab, dangerous for prod.
  # Real AWS: set false and require manual record cleanup before zone deletion.
  force_destroy = var.force_destroy

  tags = merge(local.common_tags, {
    Name = local.name
  })
}

# ── Query logging ─────────────────────────────────────────────────────────────
# Logs every DNS query to CloudWatch — audit trail for:
# - Detecting DNS exfiltration (data smuggled via DNS queries)
# - Debugging resolution issues
# - Monitoring request patterns (who's querying what)
# Real AWS: forward to S3 instead of CloudWatch for long-term retention + Athena queries.
resource "aws_route53_query_log" "this" {
  count = var.enable_query_logging ? 1 : 0

  zone_id                  = aws_route53_zone.this.zone_id
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.query_log[0].arn

  depends_on = [aws_cloudwatch_log_group.query_log]
}

resource "aws_cloudwatch_log_group" "query_log" {
  count = var.enable_query_logging ? 1 : 0

  name              = "/aws/route53/${aws_route53_zone.this.name}"
  retention_in_days = var.query_log_retention_days

  tags = merge(local.common_tags, {
    Name = "/aws/route53/${aws_route53_zone.this.name}"
  })
}

# ── Records ───────────────────────────────────────────────────────────────────
# for_each on a map of record definitions — clean, extendable, zero repetition.
# Each record = one DNS entry. Supports A, CNAME, and ALIAS types.
#
# Real AWS aliases: use aws_route53_record with alias{} block pointing at
# ALB/CloudFront/S3 — free, works at zone apex, native health check integration.
# Ministack: aliases may not resolve; use CNAME/A for local lab.
resource "aws_route53_record" "this" {
  for_each = var.records

  zone_id = aws_route53_zone.this.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = lookup(each.value, "ttl", var.default_ttl)

  # Route by record type — only one of these blocks is populated per record.
  records = each.value.type == "CNAME" || each.value.type == "A" ? (
    length(lookup(each.value, "values", [])) > 0 ? each.value.values : []
  ) : null

  # Alias records (ALB, CloudFront, S3 website endpoints).
  # Free, works at zone apex, native AWS health check integration.
  # Ministack: alias evaluation may not work — use CNAME/A instead.
  dynamic "alias" {
    for_each = each.value.type == "A" && lookup(each.value, "alias_target", null) != null ? [1] : []
    content {
      name                   = each.value.alias_target.dns_name
      zone_id                = each.value.alias_target.hosted_zone_id
      evaluate_target_health = lookup(each.value.alias_target, "evaluate_target_health", false)
    }
  }

  # Health check routing — attach an existing health_check_id to this record.
  # Used for failover routing policies: if the endpoint fails health checks,
  # Route53 stops returning this record in DNS responses.
  health_check_id = lookup(each.value, "health_check_id", null)

  # Multi-value answer routing: returns up to 8 healthy records per query.
  # Used for simple client-side load balancing without an ALB.
  # Requires set_identifier alongside multivalue — both or neither.
  multivalue_answer_routing_policy = lookup(each.value, "multivalue", null) != null ? lookup(each.value, "multivalue", false) : null
  set_identifier                   = lookup(each.value, "multivalue", null) != null ? "${each.key}-${each.value.name}" : null
}

# ── Health checks ─────────────────────────────────────────────────────────────
# Endpoint health monitoring — TCP/HTTP/HTTPS probes from Route53's global
# health checker fleet. Used with failover routing to redirect traffic away
# from unhealthy endpoints.
#
# Real AWS: these are per-endpoint. One health check = one monitored target.
# For ALB: use ALB's built-in health checks instead (free, more granular).
# For non-AWS endpoints: Route53 health checks are the standard approach.
resource "aws_route53_health_check" "this" {
  for_each = var.health_checks

  # Endpoint to monitor
  fqdn             = lookup(each.value, "fqdn", null)
  ip_address       = lookup(each.value, "ip_address", null)
  port             = each.value.port
  type             = each.value.type
  resource_path    = lookup(each.value, "resource_path", "/")
  failure_threshold = lookup(each.value, "failure_threshold", 3)
  request_interval  = lookup(each.value, "request_interval", 30)

  # At least one of fqdn or ip_address is required by the API
  # Regions to probe from — defaults to all global regions
  regions = lookup(each.value, "regions", null)

  # CloudWatch alarm integration — fire when health check fails N times
  # Real AWS: wire to SNS → PagerDuty/Opsgenie for on-call alerting
  measure_latency    = lookup(each.value, "measure_latency", false)
  invert_healthcheck = lookup(each.value, "invert_healthcheck", false)

  tags = merge(local.common_tags, {
    Name = "${local.name}-${each.key}"
  })
}
