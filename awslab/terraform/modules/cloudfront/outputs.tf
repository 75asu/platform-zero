output "distribution_id" {
  description = "CloudFront distribution ID — used for invalidation commands"
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.this.arn
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name — use as CNAME target"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "distribution_hosted_zone_id" {
  description = "Hosted zone ID for this distribution — use in Route53 alias records"
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}

output "oac_id" {
  description = "Origin Access Control ID — null when no S3 origin"
  value       = var.s3_origin_bucket != null ? aws_cloudfront_origin_access_control.s3[0].id : null
}
