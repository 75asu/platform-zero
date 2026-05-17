# Orchestration root for all environments.
# This file exists so `terragrunt run --all apply` discovers dev/ and staging/ units.
# No actual Terraform resources are defined here.

exclude {
  if      = true
  actions = ["all"]
}
