# ========================================
# Local Values
# ========================================
# Local values are used for computed or reusable values within the module.
# They help reduce repetition and make the configuration more maintainable.
locals {
  # Extract the module name from the current path for labeling
  # This helps identify which Terraform module created the resources
  project_path = basename(abspath(path.module))
}
