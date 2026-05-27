locals {
  name = "${var.project}-${var.environment}"
}

# ── Service accounts ───────────────────────────────────────────────────────────
# Creates one service account per logical service (app, worker, ci).
# In real GCP: also create google_project_iam_custom_role and bind each SA
# to it with google_project_iam_member. MiniSky does not implement
# cloudresourcemanager.googleapis.com (project-level IAM policy), so those
# resources are omitted here. Resource-level IAM bindings (e.g. bucket, topic)
# are handled in each service module where the resource is defined.

resource "google_service_account" "services" {
  for_each     = var.service_accounts
  account_id   = "${local.name}-${each.key}"
  display_name = "${local.name} ${each.key}"
  project      = var.project_id
}
