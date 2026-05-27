variable "project" {
  description = "Project name prefix used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "secrets" {
  description = "Map of secret short names to values. Secret IDs become {project}-{env}-{key}. Values are stored as secret versions."
  type        = map(string)
  # sensitive = true omitted: Terraform cannot use sensitive maps as for_each keys.
  # In real GCP: source secret values from a secure store (Vault, SOPS) rather
  # than hardcoding in tfvars, and mark individual outputs sensitive as needed.
  default = {}
}

variable "accessor_service_account" {
  description = "Service account email granted secretmanager.secretAccessor on all secrets in this module. Leave empty to skip IAM binding."
  type        = string
  default     = ""
}
