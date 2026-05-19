output "alb_arn" {
  description = "ALB ARN — pass to WAF module for web ACL association"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "ALB DNS name — use as Route53 alias target or CNAME value"
  value       = aws_lb.this.dns_name
}

output "alb_hosted_zone_id" {
  description = "ALB canonical hosted zone ID — required for Route53 alias records"
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "Target group ARN — pass to ECS service load_balancer block"
  value       = aws_lb_target_group.this.arn
}

output "alb_sg_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "ecs_sg_id" {
  description = "ECS tasks security group ID — pass to ECS service network_configuration"
  value       = aws_security_group.ecs.id
}

output "listener_arn" {
  description = "HTTP listener ARN — used for listener rule attachments"
  value       = aws_lb_listener.http.arn
}

output "arn_suffix" {
  description = "ALB ARN suffix (app/{name}/{id}) — used as CloudWatch dimension for ALB metrics"
  value       = aws_lb.this.arn_suffix
}
