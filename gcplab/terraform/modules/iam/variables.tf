variable "project" {
  description = "Project name prefix used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID — used as the namespace in MiniSky, real project ID in GCP"
  type        = string
}

variable "service_accounts" {
  description = "Map of service account short names to create. Key is appended to {project}-{env}-. Example: { app = {}, worker = {} }"
  type        = map(any)
  default     = {}
}

variable "custom_role_permissions" {
  description = "List of GCP IAM permission strings for the shared application custom role"
  type        = list(string)
  default     = []
}
