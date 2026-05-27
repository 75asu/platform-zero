locals {
  name = "${var.project}-${var.environment}"
}

# ── Cluster ────────────────────────────────────────────────────────────────────

resource "google_container_cluster" "this" {
  name     = local.name
  location = var.location
  project  = var.project_id

  # MiniSky's GKE shim returns the cluster without a nodePools array in GET,
  # which crashes the Terraform provider when it tries to read node pool config.
  # remove_default_node_pool = true suppresses node pool creation in the
  # cluster spec and tells the provider not to expect NodePools in the response.
  # The provider still creates the cluster and the LRO completes correctly.
  #
  # In real GCP: remove remove_default_node_pool and set a separate
  # google_container_node_pool with autoscaling + workload identity.
  remove_default_node_pool = true
  initial_node_count       = 1 # required when remove_default_node_pool = true

  # Allow terraform destroy to succeed.
  # In real GCP production: remove this (default true prevents accidental deletion).
  deletion_protection = false
}

# ── IAM ────────────────────────────────────────────────────────────────────────
# MiniSky does not implement project-level IAM, so google_project_iam_member
# is omitted here. In real GCP: bind roles/container.developer to the app
# service account so it can interact with the cluster API.
