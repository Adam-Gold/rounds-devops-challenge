# Cloud Build Terraform Module

This module creates a Google Cloud Build pipeline that automatically builds Android applications when ZIP files are uploaded to a GCS bucket.

## Resources Created

### Core Resources
- **google_pubsub_topic**: Message queue for GCS notifications
- **google_storage_notification**: Configures GCS to send notifications
- **google_cloudbuild_trigger**: Defines the build pipeline

### IAM Resources
- **google_service_account**: Dedicated SA for Cloud Build
- **google_project_iam_member**: Role bindings for the SA
- **google_pubsub_topic_iam_member**: Allows GCS to publish messages

## Build Pipeline Steps

### Step 1: Download File from GCS
- Uses `gcr.io/cloud-builders/gcloud` image
- Extracts file information from Pub/Sub message
- Downloads the ZIP file to workspace

### Step 2: Validate and Unzip
- Verifies the file is a valid ZIP
- Extracts contents to `/workspace/app`
- Identifies the project directory

### Step 3: Build Android Project
- Uses `ghcr.io/cirruslabs/android-sdk:35-ndk` image
- Runs Gradle build with appropriate flags
- Generates APK files

### Step 4: Send Build Notification
- Checks build status
- Sends webhook notification
- Includes build logs URL

## IAM Permissions

The module creates a service account with these roles:
- `roles/cloudbuild.builds.editor` - Manage builds
- `roles/pubsub.publisher` - Publish messages
- `roles/pubsub.subscriber` - Subscribe to topics
- `roles/storage.objectViewer` - Read GCS objects
- `roles/logging.logWriter` - Write logs

### Modifying Gradle Commands
Update the build command in Step 3:
```bash
./gradlew clean assembleDebug --no-daemon --stacktrace
```

## Best Practices

1. **Version Control**: Pin Docker image versions for consistency
2. **Secrets**: Use Secret Manager for sensitive data
3. **Monitoring**: Enable Cloud Build logs and metrics
4. **Testing**: Test with small projects first
5. **Caching**: Leverage Docker layer caching

## Limitations

- Only supports ZIP file uploads
- Assumes Gradle-based Android projects
- Single APK output (no app bundles)
- No artifact storage (APKs not saved)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.1 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 6.48.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_cloudbuild_trigger.gcs_object_trigger](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudbuild_trigger) | resource |
| [google_project_iam_member.cloud_build_sa_roles](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_pubsub_topic.cloud_build_topic](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic) | resource |
| [google_pubsub_topic_iam_member.gcs_pubsub_publisher](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic_iam_member) | resource |
| [google_service_account.cloud_build_gcs_trigger_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_storage_notification.cloud_build_notification](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_notification) | resource |
| [google_storage_project_service_account.gcs_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/storage_project_service_account) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | The name of the GCS bucket where Android ZIP files will be uploaded. This bucket must already exist or be created separately. | `string` | n/a | yes |
| <a name="input_cloudbuild_trigger_name"></a> [cloudbuild\_trigger\_name](#input\_cloudbuild\_trigger\_name) | The name of the Cloud Build trigger. Must be unique within the project. | `string` | `"gcs-object-trigger"` | no |
| <a name="input_gradle_version"></a> [gradle\_version](#input\_gradle\_version) | The version of Gradle to use for the build. | `string` | `"8.5"` | no |
| <a name="input_is_notification_enabled"></a> [is\_notification\_enabled](#input\_is\_notification\_enabled) | Enable or disable webhook notifications. Set to false to disable all notifications regardless of webhook\_url value. | `bool` | `true` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID where all resources will be created. Must have billing enabled and required APIs activated. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The GCP region for regional resources. Note that Cloud Build and Pub/Sub are global services. | `string` | `"us-central1"` | no |
| <a name="input_service_account_id"></a> [service\_account\_id](#input\_service\_account\_id) | The ID for the Cloud Build service account. Must be 6-30 characters, lowercase letters, numbers, and hyphens. | `string` | `"cloud-build-gcs-trigger-sa"` | no |
| <a name="input_topic_name"></a> [topic\_name](#input\_topic\_name) | The name of the Pub/Sub topic that receives GCS notifications. | `string` | `"cloud-build-gcs-trigger-topic"` | no |
| <a name="input_webhook_url"></a> [webhook\_url](#input\_webhook\_url) | The webhook URL to send build notifications to. Can be any HTTP(S) endpoint that accepts POST requests with JSON payloads. Leave empty to disable notifications. | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloudbuild_trigger_id"></a> [cloudbuild\_trigger\_id](#output\_cloudbuild\_trigger\_id) | ID of the Cloud Build trigger |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the Cloud Build service account |
<!-- END_TF_DOCS -->
