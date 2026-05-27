locals {
  name = "${var.project}-${var.environment}"
}

# ── Database instance ──────────────────────────────────────────────────────────

resource "google_sql_database_instance" "this" {
  name             = local.name
  project          = var.project_id
  database_version = var.database_version
  region           = var.region

  # deletion_protection = false required for lab — prevents terraform destroy from
  # failing on a live instance. Set true in prod.
  deletion_protection = false

  # MiniSky's sqladmin shim supports CREATE but not PATCH on instances.
  # ignore_changes = [settings] prevents the post-create PATCH that the
  # Google provider issues to apply backup/ip settings separately.
  # In real GCP: remove this lifecycle block.
  lifecycle {
    ignore_changes = [settings]
  }

  settings {
    # Tier controls machine size. db-f1-micro is the smallest (shared vCPU).
    # In real GCP: db-g1-small for dev, db-n1-standard-2+ for staging/prod.
    tier = var.tier

    # Custom Postgres parameters. Changes to pending-reboot parameters require
    # an instance restart — plan for a maintenance window in prod.
    dynamic "database_flags" {
      for_each = var.database_flags
      content {
        name  = database_flags.key
        value = database_flags.value
      }
    }

    backup_configuration {
      enabled = var.backup_enabled
    }

    ip_configuration {
      # ipv4_enabled = true: instance gets a public IP (required in Ministack).
      # In real GCP: use private IP via VPC peering (Cloud SQL Private Service Connect).
      ipv4_enabled = true
    }
  }
}

# ── Database ───────────────────────────────────────────────────────────────────

resource "google_sql_database" "this" {
  name     = var.database_name
  instance = google_sql_database_instance.this.name
  project  = var.project_id
}

# ── User ───────────────────────────────────────────────────────────────────────

resource "google_sql_user" "app" {
  name     = var.db_user
  instance = google_sql_database_instance.this.name
  password = var.db_password
  project  = var.project_id
}
