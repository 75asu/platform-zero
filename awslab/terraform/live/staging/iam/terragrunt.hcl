include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/iam"
}

inputs = {
  environment = "staging"

  github_org  = "75asu"
  github_repo = "platform-zero"

  # Floci doesn't implement CreateOpenIDConnectProvider — skip in lab.
  # In real AWS: remove this line (default = true).
  create_oidc_provider = false

  # Floci doesn't implement PutRolePermissionsBoundary — disable locally.
  enable_permission_boundary = false
}
