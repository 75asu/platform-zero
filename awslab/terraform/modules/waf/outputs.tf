output "web_acl_id" {
  description = "WAF web ACL ID"
  value       = aws_wafv2_web_acl.this.id
}

output "web_acl_arn" {
  description = "WAF web ACL ARN — pass to aws_wafv2_web_acl_association or use as reference"
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_capacity" {
  description = "Total WCU capacity consumed by this web ACL"
  value       = aws_wafv2_web_acl.this.capacity
}

output "ip_set_arns" {
  description = "Map of IP set keys → ARNs"
  value = {
    for k, v in aws_wafv2_ip_set.this :
    k => v.arn
  }
}

output "rule_group_arns" {
  description = "Map of rule group keys → ARNs"
  value = {
    for k, v in aws_wafv2_rule_group.this :
    k => v.arn
  }
}

output "log_group_name" {
  description = "CloudWatch log group for WAF logs — null when logging disabled"
  value       = var.enable_logging ? aws_cloudwatch_log_group.waf[0].name : null
}
