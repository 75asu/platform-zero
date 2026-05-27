locals {
  name = "${var.project}-${var.environment}-${var.service_name}"
}

# ── Cloud Run v2 service ───────────────────────────────────────────────────────

resource "google_cloud_run_v2_service" "this" {
  name     = local.name
  project  = var.project_id
  location = var.region

  template {
    service_account = var.service_account_email != "" ? var.service_account_email : null

    containers {
      image = var.container_image

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }

      # Env vars injected at container startup.
      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }
    }

    # Scaling: min 0 = scale to zero when idle (cost saving, cold start penalty).
    # min 1+ = always-warm, no cold start, costs more.
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }
  }
}

# ── IAM ────────────────────────────────────────────────────────────────────────
# MiniSky's Cloud Run shim does not implement service-level IAM policies.
# Omitted here.
# In real GCP: add google_cloud_run_v2_service_iam_member with member = "allUsers"
# and role = "roles/run.invoker" when allow_unauthenticated = true.
