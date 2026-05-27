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

variable "location" {
  description = "Cluster location. Regional (us-central1) for HA; zonal (us-central1-a) for dev cost savings."
  type        = string
  default     = "us-central1"
}

variable "node_count" {
  description = "Initial node count. Required when remove_default_node_pool = true; nodes are not actually created."
  type        = number
  default     = 1
}

variable "machine_type" {
  description = "Compute machine type for cluster nodes. Informational only — MiniSky ignores this. Used in real GCP node pool."
  type        = string
  default     = "n1-standard-2"
}

variable "disk_size_gb" {
  description = "Boot disk size in GB per node. Informational only — MiniSky ignores this. Used in real GCP node pool."
  type        = number
  default     = 30
}
