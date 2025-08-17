# ========================================
# Terraform State Backend Configuration
# ========================================
# Configures where Terraform stores its state file.
# Using local backend for development. Can be changed to remote
# backends like GCS, S3, or Terraform Cloud for team collaboration.
#
# Example GCS backend configuration:
# terraform {
#   backend "gcs" {
#     bucket = "my-terraform-state-bucket"
#     prefix = "cloud-build/state"
#   }
# }
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
