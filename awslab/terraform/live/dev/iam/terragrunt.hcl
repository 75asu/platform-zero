include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/iam"
}

inputs = {
  environment = "dev"

  github_org  = "75asu"
  github_repo = "platform-zero"

  # Ministack doesn't implement PutRolePermissionsBoundary — disable locally.
  # In real AWS this would be true (the module default).
  enable_permission_boundary = false

  # app_queue_arn left empty — wired in Phase 2 (SQS)
  # cross_account_trusted_account_id left empty — cross-account role not created
}
