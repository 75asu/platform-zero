include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/ec2"
}

dependency "iam" {
  config_path = "../iam"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    permission_boundary_arn = "arn:aws:iam::000000000000:policy/mock-boundary"
  }
}

inputs = {
  environment = "dev"

  # Ministack: PutRolePermissionsBoundary not supported — skip boundary.
  # In real AWS, wire this: permission_boundary_arn = dependency.iam.outputs.permission_boundary_arn
  permission_boundary_arn = ""

  # Ministack: data source won't find real AMIs — provide a dummy ID.
  ami_id_override = "ami-12345678"

  # Ministack: aws_instance is not fully supported — skip it.
  # IAM role, policy, attachment, and instance profile still apply.
  # In real AWS, remove this line.
  create_instance = false

  # Ministack limitations — set both to true in real AWS.
  enable_imdsv2       = false
  encrypt_root_volume = false
}
