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

variable "region" {
  description = "GCP region to deploy the Cloud Run service"
  type        = string
  default     = "us-central1"
}

variable "service_name" {
  description = "Short service name appended to {project}-{env}-. Example: api"
  type        = string
  default     = "api"
}

variable "container_image" {
  description = "Container image to run. In prod: use a pinned digest from Artifact Registry."
  type        = string
  default     = "nginx:latest"
}

variable "cpu" {
  description = "CPU limit per instance. '1' = 1 vCPU. Fractional allowed: '0.5' = 500m."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory limit per instance. '512Mi', '1Gi', etc."
  type        = string
  default     = "512Mi"
}

variable "min_instances" {
  description = "Minimum number of instances. 0 = scale to zero (cold start). 1+ = always warm."
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of instances. Controls cost ceiling and concurrency ceiling."
  type        = number
  default     = 5
}

variable "env_vars" {
  description = "Map of environment variable names to values injected into the container at startup."
  type        = map(string)
  default     = {}
}

variable "service_account_email" {
  description = "Service account the Cloud Run service runs as. Leave empty to use the default Compute service account."
  type        = string
  default     = ""
}

variable "allow_unauthenticated" {
  description = "If true, grant roles/run.invoker to allUsers (public endpoint). If false, authentication is required."
  type        = bool
  default     = false
}
