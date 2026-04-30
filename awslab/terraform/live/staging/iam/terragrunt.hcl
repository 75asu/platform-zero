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

  # Ministack doesn't implement PutRolePermissionsBoundary — disable locally.
  enable_permission_boundary = false
}
