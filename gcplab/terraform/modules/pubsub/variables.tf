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

variable "topic_name" {
  description = "Short topic name appended to {project}-{env}-. Example: orders"
  type        = string
}

variable "ack_deadline_seconds" {
  description = "Max seconds for a subscriber to ack a message before Pub/Sub re-delivers it. Match to max processing time."
  type        = number
  default     = 60
}

variable "message_retention_duration" {
  description = "How long undelivered messages are retained. Format: Ns (seconds). 604800s = 7 days."
  type        = string
  default     = "604800s"
}

variable "max_delivery_attempts" {
  description = "Number of delivery attempts before routing a message to the dead letter topic."
  type        = number
  default     = 5
}

variable "retry_minimum_backoff" {
  description = "Minimum backoff between delivery attempts. Format: Ns."
  type        = string
  default     = "10s"
}

variable "retry_maximum_backoff" {
  description = "Maximum backoff between delivery attempts. Format: Ns."
  type        = string
  default     = "600s"
}

variable "publisher_service_account" {
  description = "Service account email allowed to publish to this topic. Leave empty to skip IAM binding."
  type        = string
  default     = ""
}

variable "subscriber_service_account" {
  description = "Service account email allowed to subscribe (pull) from this topic. Leave empty to skip IAM binding."
  type        = string
  default     = ""
}
