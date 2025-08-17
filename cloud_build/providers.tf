# ========================================
# Terraform Version Requirements
# ========================================
terraform {
  required_version = ">= 1.10.1"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

# ========================================
# Google Cloud Provider Configuration
# ========================================
# Configures the Google Cloud Provider with project and region.
# Default labels are applied to all resources for tracking.
provider "google" {
  project = var.project_id
  region  = var.region

  # Default labels applied to all resources
  # These help with cost tracking and resource management
  default_labels = {
    terraform = "true"                    # Indicates resource managed by Terraform
    repo      = "rounds-devops-challenge" # Source repository
    code      = local.project_path        # Specific module path
  }
}
