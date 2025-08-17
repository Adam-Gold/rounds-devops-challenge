# Google Cloud Build Android Pipeline

A Terraform-based infrastructure for automatically building Android applications when ZIP files are uploaded to Google Cloud Storage. This solution creates a serverless CI/CD pipeline that triggers on file uploads, builds Android APKs, and sends webhook notifications with build results.

## 🚀 Features

- **Automatic Triggering**: Builds start automatically when ZIP files are uploaded to GCS
- **Android Build Support**: Pre-configured with Android SDK 35 and Java 17
- **Build Notifications**: Webhook notifications for build success/failure with direct links to logs
- **Infrastructure as Code**: Fully managed through Terraform/OpenTofu
- **Scalable**: Leverages Google Cloud Build's serverless architecture
- **Secure**: Uses dedicated service accounts with minimal permissions

## 📋 Prerequisites

- Google Cloud Project with billing enabled
- Terraform/OpenTofu installed (v1.0+)
- `gcloud` CLI configured with appropriate permissions
- A GCS bucket for storing Android project ZIP files
- (Optional) A webhook endpoint for notifications (e.g., webhook.site)

## 🛠️ Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/rounds-devops-challenge.git
cd rounds-devops-challenge
```

### 2. Configure Variables

Create a `terraform.tfvars` file or use the example:

```bash
cd cloud_build
cp terraform.tfvars.example vars/terraform.tfvars
```

Edit the values according to your environment:

```hcl
bucket_name             = "your-android-builds-bucket"
project_id              = "your-gcp-project-id"
region                  = "us-central1"
webhook_url             = "https://webhook.site/your-unique-id"
is_notification_enabled = true
```

### 3. Initialize and Apply Terraform

```bash
# Initialize Terraform
terraform init

# Review the planned changes
terraform plan -var-file=vars/terraform.tfvars -out=$(basename ${PWD}).plan

# Apply the infrastructure
terraform apply $(basename ${PWD}).plan && rm -rf $(basename ${PWD}).plan
```

### 4. Enable Required APIs

If not already enabled, the following APIs need to be active:
- Cloud Build API
- Pub/Sub API
- Cloud Storage API

```bash
gcloud services enable cloudbuild.googleapis.com
gcloud services enable pubsub.googleapis.com
gcloud services enable storage-component.googleapis.com
```

## 🔧 How It Works

### 1. File Upload Detection
When a file is uploaded to the configured GCS bucket, a notification is sent to a Pub/Sub topic.

### 2. Build Trigger
The Cloud Build trigger subscribes to the Pub/Sub topic and starts a build when it receives a notification about a new ZIP file.

### 3. Build Process
The build process consists of several steps:
   - **Download**: Retrieves the ZIP file from GCS
   - **Validate**: Checks that the uploaded file is a valid ZIP
   - **Extract**: Unzips the Android project
   - **Build**: Compiles the Android APK using Gradle
   - **Notify**: Sends webhook notification with build results

### 4. Notifications
Build results are sent to the configured webhook URL with:
   - Build status (SUCCESS/FAILURE)
   - Direct link to Cloud Build logs
   - Source file information
   - Failure reason (if applicable)

## 📊 Webhook Payload Examples

### Success Notification
```json
{
  "status": "SUCCESS",
  "project_id": "your-project-id",
  "build_id": "abc123-def456",
  "trigger_name": "gcs-object-trigger",
  "source_object": "my-android-app.zip",
  "source_bucket": "your-android-builds-bucket",
  "build_log_url": "https://console.cloud.google.com/cloud-build/builds/abc123-def456?project=your-project-id",
  "timestamp": "2024-01-15T10:30:00Z",
  "message": "Android APK build completed successfully"
}
```

### Failure Notification
```json
{
  "status": "FAILURE",
  "project_id": "your-project-id",
  "build_id": "xyz789-uvw012",
  "trigger_name": "gcs-object-trigger",
  "source_object": "broken-app.zip",
  "source_bucket": "your-android-builds-bucket",
  "build_log_url": "https://console.cloud.google.com/cloud-build/builds/xyz789-uvw012?project=your-project-id",
  "timestamp": "2024-01-15T10:35:00Z",
  "failure_reason": "Android build compilation failed",
  "message": "Android APK build failed - check logs for details"
}
```

## 🔍 Monitoring & Debugging

### View Build Logs
1. Go to [Cloud Build Console](https://console.cloud.google.com/cloud-build/builds)
2. Click on the build ID to see detailed logs
3. Or use the direct link from the webhook notification

### Common Issues

#### VPC Service Controls Error
If you see "Request is prohibited by organization's policy", you may need to:
1. Add your project to the VPC Service Controls perimeter
2. Or create an access level for Cloud Build
3. Contact your organization administrator

#### Build Failures
Check the build logs for:
- Missing dependencies
- Gradle configuration issues
- Android SDK version mismatches
- Network connectivity problems

## 🔐 Security Considerations

- **Service Account**: Uses a dedicated service account with minimal permissions
- **IAM Roles**: Only necessary roles are granted:
  - `roles/cloudbuild.builds.editor`
  - `roles/pubsub.publisher`
  - `roles/pubsub.subscriber`
  - `roles/storage.objectViewer`
  - `roles/logging.logWriter`
- **Bucket Permissions**: The service account only has read access to the GCS bucket

## 🙏 Acknowledgments

- Google Cloud Build team for the platform
- Cirrus Labs for the Android SDK Docker image
- The Android development community
