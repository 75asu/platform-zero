include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/s3"
}

inputs = {
  bucket_name = "platform-zero-staging-app-data"
  environment = "staging"
}
