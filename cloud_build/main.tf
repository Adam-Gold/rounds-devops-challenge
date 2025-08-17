# ========================================
# Pub/Sub Topic for GCS Notifications
# ========================================
# This topic receives messages when files are uploaded to the GCS bucket.
# It acts as the communication channel between GCS and Cloud Build.
resource "google_pubsub_topic" "cloud_build_topic" {
  name = var.topic_name
}

# ========================================
# GCS Bucket Notification Configuration
# ========================================
# Configures the GCS bucket to send notifications to the Pub/Sub topic
# whenever a new object is uploaded (OBJECT_FINALIZE event).
# The notification includes metadata about the uploaded file.
resource "google_storage_notification" "cloud_build_notification" {
  bucket         = var.bucket_name
  event_types    = ["OBJECT_FINALIZE"] # Triggered when upload completes
  payload_format = "JSON_API_V1"       # Standard GCS notification format
  topic          = google_pubsub_topic.cloud_build_topic.id

  # Ensure the topic exists and GCS has permission to publish before creating notification
  depends_on = [
    google_pubsub_topic.cloud_build_topic,
    google_pubsub_topic_iam_member.gcs_pubsub_publisher
  ]
}

# ========================================
# Cloud Build Trigger Definition
# ========================================
# This trigger listens to the Pub/Sub topic and starts a build process
# when it receives a notification about a new file upload.
# The trigger uses a custom service account with minimal permissions.
resource "google_cloudbuild_trigger" "gcs_object_trigger" {
  name            = var.cloudbuild_trigger_name
  description     = "Triggers a build when an object is uploaded to the bucket"
  service_account = google_service_account.cloud_build_gcs_trigger_sa.id

  # Configure trigger to listen to Pub/Sub messages
  pubsub_config {
    topic = google_pubsub_topic.cloud_build_topic.id
  }

  # ========================================
  # Substitution Variables
  # ========================================
  # Extract key information from the Pub/Sub message attributes.
  # These variables are available to all build steps as environment variables.
  substitutions = {
    _BUCKET_ID = "$(body.message.attributes.bucketId)" # Source bucket name
    _OBJECT_ID = "$(body.message.attributes.objectId)" # Uploaded file name/path
    _BUILD_ID  = "$BUILD_ID"                           # Cloud Build ID
  }

  # ========================================
  # Build Configuration
  # ========================================
  # Defines the actual build steps that run when triggered.
  # Steps are executed sequentially in the order defined.
  build {
    # Build environment options for faster execution
    options {
      logging = "CLOUD_LOGGING_ONLY"  # Store logs in Cloud Logging only
      env     = ["DOCKER_BUILDKIT=1"] # Enable Docker BuildKit for layer caching
    }

    timeout = "1200s" # 20 minutes timeout

    # ========================================
    # Step 0: Pre-pull Android SDK Image (for caching)
    # ========================================
    # Pre-pulls the Android SDK image to cache it for faster subsequent usage
    step {
      name       = "gcr.io/cloud-builders/docker"
      id         = "Cache Android SDK Image"
      entrypoint = "bash"
      args       = [
        "-c",
        <<-EOT
                echo "Pre-pulling Android SDK image for faster build..."
                docker pull ghcr.io/cirruslabs/android-sdk:35-ndk
                echo "Android SDK image cached successfully"
                EOT
      ]
    }

    # ========================================
    # Step 1: Download File from GCS
    # ========================================
    # Downloads the uploaded ZIP file from GCS to the build workspace.
    # Uses the bucket and object information from the Pub/Sub message.
    step {
      name       = "gcr.io/cloud-builders/gcloud"
      id         = "Download file from GCS"
      entrypoint = "bash"
      args       = [
        "-c",
        <<-EOT
                # Use substitution variables from Pub/Sub message attributes
                echo "Bucket ID: $${_BUCKET_ID}"
                echo "Object ID: $${_OBJECT_ID}"

                # Set variables from substitutions
                BUCKET_NAME="$${_BUCKET_ID}"
                OBJECT_NAME="$${_OBJECT_ID}"

                # Validate we have both values
                if [[ -z "$$BUCKET_NAME" || -z "$$OBJECT_NAME" ]]; then
                    echo "Error: Missing bucket name or object name from Pub/Sub attributes"
                    echo "Bucket: '$$BUCKET_NAME'"
                    echo "Object: '$$OBJECT_NAME'"
                    echo "This might indicate the GCS notification format is different than expected"
                    exit 1
                fi

                echo "Processing file: $$OBJECT_NAME from bucket: $$BUCKET_NAME"
                echo "export FILENAME=$$OBJECT_NAME" >> /workspace/env_vars.sh
                echo "export BUCKET_NAME=$$BUCKET_NAME" >> /workspace/env_vars.sh

                # Download the file from GCS
                echo "Downloading gs://$$BUCKET_NAME/$$OBJECT_NAME"
                gsutil cp "gs://$$BUCKET_NAME/$$OBJECT_NAME" "/workspace/$$OBJECT_NAME"
                EOT
      ]
    }

    # ========================================
    # Step 2: Validate and Extract ZIP File
    # ========================================
    # Validates that the downloaded file is a ZIP archive and extracts it.
    # Identifies the actual project directory within the extracted contents.
    step {
      name       = "gcr.io/cloud-builders/gcloud"
      id         = "Validate and Unzip File"
      entrypoint = "bash"
      args       = [
        "-c",
        <<-EOT
                # Install file utility for file type detection
                apt-get -qq update && apt-get install -yq file unzip

                # Source the environment variables
                source /workspace/env_vars.sh

                # Verify the file is a zip file
                if file --mime-type /workspace/$$FILENAME | grep -q 'application/zip'; then
                  echo "The file $$FILENAME is a zip file"
                  echo "Unzipping the file $$FILENAME"
                  mkdir -p /workspace/app
                  unzip -qq /workspace/$$FILENAME -d /workspace/app
                  echo "Unzipping the file $$FILENAME completed"

                  # Find the actual project directory (first subdirectory in app/)
                  PROJECT_DIR=$$(find /workspace/app -maxdepth 1 -type d | grep -v "^/workspace/app$$" | head -1)
                  echo "Found project directory: $$PROJECT_DIR"
                  echo "export PROJECT_DIR=$$PROJECT_DIR" >> /workspace/env_vars.sh
                else
                  echo "The file $$FILENAME is not a zip file"
                  echo "Exiting the build"
                  exit 1
                fi
                EOT
      ]
    }

    # ========================================
    # Step 3: Build Android Project
    # ========================================
    # Builds the Android application using Gradle.
    # Uses a pre-configured Docker image with Android SDK 35 and Java 17.
    # Runs 'gradlew clean assembleDebug' to create a debug APK.
    step {
      name       = "ghcr.io/cirruslabs/android-sdk:35-ndk"
      id         = "Build Android Project"
      entrypoint = "bash"
      args       = [
        "-c",
        <<-EOT
                # Source environment variables to get the project directory
                source /workspace/env_vars.sh

                # Navigate to project directory and run optimized build
                cd "$$PROJECT_DIR"

                # Debug: Check what's available in the image
                echo "Checking available build tools..."
                echo "Java version: $$(java -version 2>&1 | head -1)"
                echo "Android SDK: $$ANDROID_HOME"
                echo "Gradlew exists: $$([ -f "./gradlew" ] && echo "YES" || echo "NO")"
                echo "Gradle in PATH: $$(command -v gradle >/dev/null 2>&1 && echo "YES" || echo "NO")"
                echo "SDK command: $$(command -v sdk >/dev/null 2>&1 && echo "YES" || echo "NO")"

                # Configure Gradle for optimal performance
                export GRADLE_OPTS="-Xmx4g -XX:MaxMetaspaceSize=512m -XX:+UseParallelGC"
                export GRADLE_USER_HOME="/workspace/.gradle"

                # Run optimized Android build
                BUILD_EXIT_CODE=0
                if [[ -f "./gradlew" ]]; then
                    chmod +x ./gradlew
                    echo "Building Android project with Gradle wrapper..."
                    ./gradlew clean assembleDebug \
                        --no-daemon \
                        --no-configuration-cache \
                        --refresh-dependencies \
                        --parallel \
                        --max-workers=4 \
                        --build-cache \
                        --quiet
                    BUILD_EXIT_CODE=$$?
                else
                    echo "No gradlew found. Installing Gradle..."
                    GRADLE_VERSION=${var.gradle_version}
                    cd /tmp
                    wget -q https://services.gradle.org/distributions/gradle-$$GRADLE_VERSION-bin.zip
                    unzip -q gradle-$$GRADLE_VERSION-bin.zip
                    export PATH="/tmp/gradle-$$GRADLE_VERSION/bin:$$PATH"

                    cd "$$PROJECT_DIR"
                    gradle clean assembleDebug \
                        --no-daemon \
                        --refresh-dependencies \
                        --parallel \
                        --quiet
                    BUILD_EXIT_CODE=$$?
                fi

                # Store build result (don't exit yet - let notification run first)
                if [ $$BUILD_EXIT_CODE -eq 0 ] && [ $$(find . -name "*.apk" -type f | wc -l) -gt 0 ]; then
                    echo "BUILD_SUCCESS=true" > /workspace/build_status.env
                    echo "Build completed successfully"
                else
                    echo "BUILD_SUCCESS=false" > /workspace/build_status.env
                    echo "BUILD_EXIT_CODE=$$BUILD_EXIT_CODE" >> /workspace/build_status.env
                    echo "Build failed (exit code: $$BUILD_EXIT_CODE)"
                fi
                EOT
      ]
    }

    # Unified notification step - always runs and checks build status
    # ========================================
    # Step 4: Send Build Status Notification
    # ========================================
    # Sends a webhook notification with the build result (success/failure).
    # Includes build metadata, logs URL, and failure reasons if applicable.
    # This step always runs, regardless of previous step outcomes.
    step {
      name       = "gcr.io/cloud-builders/gcloud"
      id         = "Send Build Notification"
      entrypoint = "bash"
      args       = [
        "-c",
        <<-EOT
                if [[ "${var.is_notification_enabled}" == "true" && -n "${var.webhook_url}" ]]; then
                    echo "Checking build status and sending notification..."
                    echo "Webhook URL: ${var.webhook_url}"

                    # Source project info
                    source /workspace/env_vars.sh 2>/dev/null || true

                    BUILD_ID="$${_BUILD_ID}"
                    # Get build log URL
                    if [[ "$$BUILD_ID" != "" ]]; then
                        BUILD_LOG_URL="https://console.cloud.google.com/cloud-build/builds/$$BUILD_ID?project=${var.project_id}"
                    else
                        BUILD_LOG_URL="https://console.cloud.google.com/cloud-build/builds?project=${var.project_id}"
                    fi

                    # Check if build was successful by looking for success marker
                    BUILD_STATUS="FAILURE"
                    MESSAGE="Android APK build failed - check logs for details"
                    FAILURE_REASON=""

                    echo "Checking for build status file..."
                    if [[ -f "/workspace/build_status.env" ]]; then
                        echo "Build status file found. Contents:"
                        cat /workspace/build_status.env
                        source /workspace/build_status.env

                        if [[ "$$BUILD_SUCCESS" == "true" ]]; then
                            BUILD_STATUS="SUCCESS"
                            MESSAGE="Android APK build completed successfully"
                            echo "Build succeeded - sending success notification"
                        else
                            echo "Build failed according to build_status.env - sending failure notification"
                            # Determine failure reason based on available info
                            if [[ -z "$$FILENAME" ]]; then
                                FAILURE_REASON="Failed to download or process source file"
                            elif [[ ! -d "/workspace/app" ]]; then
                                FAILURE_REASON="Failed to extract source archive"
                            else
                                FAILURE_REASON="Android build compilation failed"
                            fi
                        fi
                    else
                        FAILURE_REASON="Build failed - no status information available"
                    fi

                    # Prepare webhook payload (conditional fields for failure)
                    if [[ "$$BUILD_STATUS" == "SUCCESS" ]]; then
                        PAYLOAD=$$(cat <<JSON
{
  "status": "$$BUILD_STATUS",
  "project_id": "${var.project_id}",
  "build_id": "$$BUILD_ID",
  "trigger_name": "${var.cloudbuild_trigger_name}",
  "source_object": "$$FILENAME",
  "source_bucket": "$$BUCKET_NAME",
  "build_log_url": "$$BUILD_LOG_URL",
  "timestamp": "$$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "message": "$$MESSAGE"
}
JSON
)
                    else
                        PAYLOAD=$$(cat <<JSON
{
  "status": "$$BUILD_STATUS",
  "project_id": "${var.project_id}",
  "build_id": "$$BUILD_ID",
  "trigger_name": "${var.cloudbuild_trigger_name}",
  "source_object": "$${FILENAME:-'unknown'}",
  "source_bucket": "$${BUCKET_NAME:-'unknown'}",
  "build_log_url": "$$BUILD_LOG_URL",
  "timestamp": "$$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "failure_reason": "$$FAILURE_REASON",
  "message": "$$MESSAGE"
}
JSON
)
                    fi

                    # Send to webhook
                    echo "Sending webhook notification..."
                    echo "Payload preview: $$(echo "$$PAYLOAD")"

                    # Send webhook and capture both response and HTTP status
                    RESPONSE=$$(curl -X POST "${var.webhook_url}" \
                        -H "Content-Type: application/json" \
                        -d "$$PAYLOAD" \
                        --max-time 30 \
                        --retry 3 \
                        --retry-delay 5 \
                        --silent \
                        --show-error \
                        --write-out "HTTPSTATUS:%%{http_code}" 2>&1)

                    # Extract HTTP status code and response body
                    HTTP_STATUS=$$(echo "$$RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
                    RESPONSE_BODY=$$(echo "$$RESPONSE" | sed 's/HTTPSTATUS:[0-9]*$$//')

                    echo "HTTP Status: $$HTTP_STATUS"
                    echo "Response: $$RESPONSE_BODY"

                    # Check if webhook was successful (2xx status codes)
                    if [[ "$$HTTP_STATUS" =~ ^2[0-9][0-9]$$ ]]; then
                        echo "$$BUILD_STATUS notification sent successfully"
                    else
                        echo "ERROR: Webhook notification failed with HTTP $$HTTP_STATUS"
                        echo "Failed to send $$BUILD_STATUS notification to ${var.webhook_url}"
                        exit 1
                    fi
                else
                    echo "Notifications disabled or webhook URL not configured"
                fi
                EOT
      ]
    }

    # ========================================
    # Step 5: Fail Build if Android Build Failed
    # ========================================
    # This final step ensures the Cloud Build pipeline fails if the Android build failed,
    # even after sending the notification. This gives proper build status in Cloud Build console.
    step {
      name       = "gcr.io/cloud-builders/gcloud"
      id         = "Fail Build If Android Build Failed"
      entrypoint = "bash"
      args       = [
        "-c",
        <<-EOT
                echo "Checking final build status to determine Cloud Build result..."

                if [[ -f "/workspace/build_status.env" ]]; then
                    source /workspace/build_status.env
                    if [[ "$$BUILD_SUCCESS" == "true" ]]; then
                        echo "Android build succeeded - Cloud Build will succeed"
                        exit 0
                    else
                        echo "Android build failed - failing Cloud Build pipeline"
                        # Get the original exit code if available
                        if [[ "$$BUILD_EXIT_CODE" != 0 ]]; then
                            EXIT_CODE=$$BUILD_EXIT_CODE
                            echo "Exiting with original Android build exit code: $$EXIT_CODE"
                            exit $$EXIT_CODE
                        else
                            echo "Exiting with generic failure code"
                            exit 1
                        fi
                    fi
                else
                    echo "No build status file found - assuming failure"
                    exit 1
                fi
                EOT
      ]
    }
  }
}
