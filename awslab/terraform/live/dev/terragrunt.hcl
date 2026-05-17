# Orchestration root for dev environment.
# This file exists so `terragrunt run --all apply` discovers all child units.
# No actual Terraform resources are defined here.

exclude {
  if      = true
  actions = ["all"]
}
