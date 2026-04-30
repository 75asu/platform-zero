locals {
  environment = "staging"

  # Different project ID = isolated namespace in MiniSky.
  # In real GCP: replace with actual staging project ID.
  gcp_project = "gcplab-staging"

  minisky_endpoint = get_env("MINISKY_ENDPOINT", "http://localhost:8082")
}
