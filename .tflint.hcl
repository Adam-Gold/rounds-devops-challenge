plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "google" {
  enabled = true
  version = "0.35.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}

rule "terraform_standard_module_structure" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}
