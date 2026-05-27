locals {
  bucket_name = "${var.project}-${var.environment}-${var.bucket_suffix}"
}

# ── Bucket ─────────────────────────────────────────────────────────────────────

resource "google_storage_bucket" "this" {
  name          = local.bucket_name
  project       = var.project_id
  location      = var.location
  storage_class = var.storage_class

  # Uniform access: all access controlled via IAM — no per-object ACLs.
  # Required for new workloads; legacy ACL model is deprecated.
  uniform_bucket_level_access = true

  # force_destroy allows Terraform to delete buckets containing objects.
  # Set to false in prod to prevent accidental data loss.
  force_destroy = var.force_destroy

  # MiniSky's GCS shim does not support versioning ("fs storage type does not
  # support versioning yet"). Only include the block when actually enabled.
  # In real GCP: versioning_enabled = true is safe and recommended.
  dynamic "versioning" {
    for_each = var.versioning_enabled ? [1] : []
    content {
      enabled = true
    }
  }

  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action_type
        storage_class = lookup(lifecycle_rule.value, "storage_class", null)
      }
      condition {
        age = lifecycle_rule.value.age_days
      }
    }
  }
}

# ── IAM ────────────────────────────────────────────────────────────────────────
# MiniSky's GCS shim does not implement bucket IAM policy operations.
# Omitted here.
# In real GCP: add google_storage_bucket_iam_member for each entry in
# var.iam_members to grant the appropriate storage roles.
