# gke

Creates a GKE cluster with a minimal default node pool.

## MiniSky compatibility

| Resource | Status | Notes |
|---|---|---|
| `google_container_cluster` | ✓ | LRO verified: PENDING → RUNNING → DONE (~6s) |
| Separate node pool | not tested | use `initial_node_count` pattern instead |
| Project IAM | omitted | `cloudresourcemanager` not registered in MiniSky |

MiniSky LRO for GKE cluster creation transitions through RUNNING → DONE
in ~6 seconds. The `container_custom_endpoint` in root.hcl points the
Terraform google provider at port 8098 (nginx → MiniSky).

## Real GCP additions

In real GCP, restore and extend:
- `remove_default_node_pool = true` + separate `google_container_node_pool`
  with autoscaling (`min_node_count`, `max_node_count`) and node auto-upgrade
- `workload_metadata_config { mode = "GKE_METADATA" }` for Workload Identity
- `private_cluster_config` for private nodes
- `master_authorized_networks_config` to restrict API server access
- `google_project_iam_member` binding `roles/container.developer` to app SA
