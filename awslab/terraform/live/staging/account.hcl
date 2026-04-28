locals {
  environment = "staging"

  aws_endpoint = get_env("AWS_ENDPOINT_URL", "http://localhost:4566")

  # Different access_key = different account namespace in Ministack/LocalStack.
  # Resources created here are isolated from dev (000000000001).
  # In real AWS: replace this with an IAM role ARN for the staging account.
  access_key = "000000000002"
}
