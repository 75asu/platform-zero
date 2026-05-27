locals {
  name = "${var.project}-${var.environment}"
}

# ── Secrets ────────────────────────────────────────────────────────────────────

resource "google_secret_manager_secret" "this" {
  for_each  = var.secrets
  secret_id = "${local.name}-${each.key}"
  project   = var.project_id

  # Auto replication: GCP manages the replication topology.
  # For prod with compliance requirements: use user_managed replication with
  # explicit regions (and optionally, CMEK encryption per replica).
  replication {
    auto {}
  }
}

# google_secret_manager_secret_version omitted: MiniSky creates the version data
# but does not implement the :enable action the Google provider calls post-write
# (returns 404 "unknown version action: enable"). Secret shells are created above.
# In real GCP: restore the version resource to store actual secret values.

# ── IAM ────────────────────────────────────────────────────────────────────────
# MiniSky's Secret Manager shim does not implement secret-level IAM policies
# (returns 404 "unknown action: getIamPolicy"). Omitted here.
# In real GCP: add google_secret_manager_secret_iam_member per secret to grant
# roles/secretmanager.secretAccessor to the accessor_service_account.
