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

variable "bucket_suffix" {
  description = "Suffix appended to bucket name: {project}-{env}-{suffix}. Must be globally unique in GCP."
  type        = string
  default     = "app"
}

variable "location" {
  description = "Bucket location. Multi-region (US, EU, ASIA) or single-region (us-central1). Multi-region is more resilient and cheaper for reads."
  type        = string
  default     = "US"
}

variable "storage_class" {
  description = "Storage class. STANDARD for frequently accessed data, NEARLINE for once/month, COLDLINE for once/quarter, ARCHIVE for rare access."
  type        = string
  default     = "STANDARD"
}

variable "versioning_enabled" {
  description = "Enable object versioning. Keeps previous versions on overwrite/delete. Required for PITR-style recovery."
  type        = bool
  default     = false
}

variable "force_destroy" {
  description = "Allow Terraform to destroy a non-empty bucket. Safe for lab, set false in prod."
  type        = bool
  default     = true
}

variable "lifecycle_rules" {
  description = "List of lifecycle rules. action_type: Delete or SetStorageClass. age_days: trigger after N days. storage_class: required for SetStorageClass."
  type = list(object({
    action_type   = string
    age_days      = number
    storage_class = optional(string)
  }))
  default = []
}

variable "iam_members" {
  description = "Map of IAM bindings. Key is a label, value has role and member. member format: serviceAccount:x@y.iam.gserviceaccount.com"
  type = map(object({
    role   = string
    member = string
  }))
  default = {}
}
