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

variable "dataset_id" {
  description = "Short dataset name appended after {project}_{env}_. Example: events"
  type        = string
}

variable "location" {
  description = "BigQuery dataset location. US and EU are multi-region; us-central1 is single-region."
  type        = string
  default     = "US"
}

variable "tables" {
  description = "Map of table_id to table config. Each value must include a schema (JSON string)."
  type = map(object({
    schema = string
  }))
  default = {}
}
