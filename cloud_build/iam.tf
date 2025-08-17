# ========================================
# Service Account for Cloud Build
# ========================================
# Dedicated service account used by the Cloud Build trigger.
# This follows the principle of least privilege by granting
# only the necessary permissions for the build process.
resource "google_service_account" "cloud_build_gcs_trigger_sa" {
  account_id   = var.service_account_id
  display_name = "Cloud Build GCS Trigger Service Account"
}

# ========================================
# IAM Roles for Cloud Build Service Account
# ========================================
# Grants necessary permissions to the Cloud Build service account:
# - cloudbuild.builds.editor: Create and manage builds
# - pubsub.publisher: Publish messages (for inter-service communication)
# - pubsub.subscriber: Subscribe to Pub/Sub topics
# - storage.objectViewer: Read files from GCS buckets
# - logging.logWriter: Write build logs to Cloud Logging
resource "google_project_iam_member" "cloud_build_sa_roles" {
  for_each = toset([
    "roles/cloudbuild.builds.editor",
    "roles/pubsub.publisher",
    "roles/pubsub.subscriber",
    "roles/storage.objectViewer",
    "roles/logging.logWriter"
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_build_gcs_trigger_sa.email}"
}

# ========================================
# GCS Service Account Data Source
# ========================================
# Retrieves the email address of the Google-managed service account
# that GCS uses to publish notifications to Pub/Sub.
# This is required to grant the correct permissions.
data "google_storage_project_service_account" "gcs_account" {
  project = var.project_id
}

# ========================================
# Pub/Sub Topic IAM Binding
# ========================================
# Grants the GCS service account permission to publish messages
# to the Pub/Sub topic. This is required for GCS notifications
# to work properly. Without this, GCS cannot send notifications
# when files are uploaded to the bucket.
resource "google_pubsub_topic_iam_member" "gcs_pubsub_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.cloud_build_topic.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}
