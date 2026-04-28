locals {
  environment = "dev"

  # get_env() reads the shell environment at runtime — no hardcoded IPs.
  # Run: source awslab/env.sh before any terragrunt command.
  aws_endpoint = get_env("AWS_ENDPOINT_URL", "http://localhost:4566")

  # access_key doubles as the account namespace in Ministack/LocalStack.
  # "test" is the bootstrap account — dev runs in the same namespace so
  # existing state and resources are picked up without migration.
  # In real AWS this becomes an IAM role ARN passed to assume_role{}.
  access_key = "test"
}
