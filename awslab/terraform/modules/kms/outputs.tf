output "key_id" {
  description = "KMS key ID — used in resource-level encryption config (e.g. aws_db_instance.kms_key_id)"
  value       = aws_kms_key.this.key_id
}

output "key_arn" {
  description = "KMS key ARN — used in IAM policy Condition keys and cross-account grants"
  value       = aws_kms_key.this.arn
}

output "alias_name" {
  description = "KMS alias name — human-readable reference for the key in console and CLI"
  value       = aws_kms_alias.this.name
}
