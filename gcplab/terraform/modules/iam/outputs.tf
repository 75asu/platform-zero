output "service_account_emails" {
  description = "Map of service account short name to full email address"
  value       = { for k, v in google_service_account.services : k => v.email }
}

output "service_account_ids" {
  description = "Map of service account short name to full resource ID"
  value       = { for k, v in google_service_account.services : k => v.id }
}
