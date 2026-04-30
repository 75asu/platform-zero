locals {
  environment = "dev"

  # GCP project ID — simulates a separate GCP project per environment.
  # MiniSky uses this as a namespace. In real GCP: replace with actual project ID.
  gcp_project = "gcplab-dev"

  # MiniSky endpoint — read from env.sh at runtime.
  # source gcplab/env.sh before any terragrunt command.
  minisky_endpoint = get_env("MINISKY_ENDPOINT", "http://localhost:8082")
}
