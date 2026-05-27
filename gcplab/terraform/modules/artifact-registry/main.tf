locals {
  name = "${var.project}-${var.environment}"
}

# ── Repository ─────────────────────────────────────────────────────────────────

resource "google_artifact_registry_repository" "this" {
  repository_id = local.name
  project       = var.project_id
  location      = var.location
  format        = var.format
  description   = "${var.project} ${var.environment} container registry"
}

# ── IAM ────────────────────────────────────────────────────────────────────────
# MiniSky's Artifact Registry shim does not implement repository-level IAM
# policies. Omitted here.
# In real GCP: add google_artifact_registry_repository_iam_member for writer
# service accounts (CI/CD) with roles/artifactregistry.writer and reader
# service accounts (Cloud Run, GKE) with roles/artifactregistry.reader.
