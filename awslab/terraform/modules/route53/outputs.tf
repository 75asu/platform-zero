output "zone_id" {
  description = "Route53 hosted zone ID — used to reference this zone in other modules"
  value       = aws_route53_zone.this.zone_id
}

output "zone_name" {
  description = "Route53 hosted zone name (the domain)"
  value       = aws_route53_zone.this.name
}

output "zone_arn" {
  description = "Route53 hosted zone ARN"
  value       = aws_route53_zone.this.arn
}

output "name_servers" {
  description = "List of name servers for this zone — delegate from your domain registrar"
  value       = aws_route53_zone.this.name_servers
}

output "record_fqdns" {
  description = "Map of record keys → fully qualified domain names"
  value = {
    for k, v in aws_route53_record.this :
    k => v.fqdn
  }
}

output "record_names" {
  description = "Map of record keys → record names (relative to zone)"
  value = {
    for k, v in aws_route53_record.this :
    k => v.name
  }
}

output "health_check_ids" {
  description = "Map of health check keys → health check IDs — pass to records via health_check_id"
  value = {
    for k, v in aws_route53_health_check.this :
    k => v.id
  }
}
