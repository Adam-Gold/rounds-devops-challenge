# ========================================
# Essential Module Outputs
# ========================================

output "service_account_email" {
  description = "Email of the Cloud Build service account"
  value       = google_service_account.cloud_build_gcs_trigger_sa.email
}

output "cloudbuild_trigger_id" {
  description = "ID of the Cloud Build trigger"
  value       = google_cloudbuild_trigger.gcs_object_trigger.id
}
