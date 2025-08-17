# ========================================
# Required Variables
# ========================================

variable "bucket_name" {
  description = "The name of the GCS bucket where Android ZIP files will be uploaded. This bucket must already exist or be created separately."
  type        = string
}

variable "project_id" {
  description = "The GCP project ID where all resources will be created. Must have billing enabled and required APIs activated."
  type        = string
}

# ========================================
# Optional Variables
# ========================================

variable "cloudbuild_trigger_name" {
  description = "The name of the Cloud Build trigger. Must be unique within the project."
  type        = string
  default     = "gcs-object-trigger"
}

variable "gradle_version" {
  description = "The version of Gradle to use for the build."
  type        = string
  default     = "8.5"
}

variable "is_notification_enabled" {
  description = "Enable or disable webhook notifications. Set to false to disable all notifications regardless of webhook_url value."
  type        = bool
  default     = true
}

variable "region" {
  description = "The GCP region for regional resources. Note that Cloud Build and Pub/Sub are global services."
  type        = string
  default     = "us-central1"
}

variable "service_account_id" {
  description = "The ID for the Cloud Build service account. Must be 6-30 characters, lowercase letters, numbers, and hyphens."
  type        = string
  default     = "cloud-build-gcs-trigger-sa"
}

variable "topic_name" {
  description = "The name of the Pub/Sub topic that receives GCS notifications."
  type        = string
  default     = "cloud-build-gcs-trigger-topic"
}

variable "webhook_url" {
  description = "The webhook URL to send build notifications to. Can be any HTTP(S) endpoint that accepts POST requests with JSON payloads. Leave empty to disable notifications."
  type        = string
  default     = ""
  sensitive   = true # Mark as sensitive to avoid logging

  validation {
    condition     = var.webhook_url == "" || can(regex("^https?://", var.webhook_url))
    error_message = "The webhook_url must be a valid HTTP or HTTPS URL, or empty string."
  }
}
