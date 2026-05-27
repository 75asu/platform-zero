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
  description = "Repository location — single region (us-central1) or multi-region (us)."
  type        = string
  default     = "us-central1"
}

variable "format" {
  description = "Repository format. DOCKER for container images. Also supports NPM, MAVEN, PYTHON, GO."
  type        = string
  default     = "DOCKER"
}

variable "writer_service_accounts" {
  description = "List of service account emails granted artifactregistry.writer (push). Typically CI deploy role."
  type        = list(string)
  default     = []
}

variable "reader_service_accounts" {
  description = "List of service account emails granted artifactregistry.reader (pull). Typically Cloud Run or GKE node SA."
  type        = list(string)
  default     = []
}
