# modules/iam

Service accounts, a shared custom role, and project IAM bindings. Account-level resources only — no per-service permissions here.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `google_service_account` (per entry) | One identity per logical service (app, worker, ci) |
| `google_project_iam_custom_role` | Least-privilege custom role scoped to this project |
| `google_project_iam_member` (per SA) | Binds every service account to the custom role |

## Key concepts

**GCP IAM vs AWS IAM**
AWS: IAM roles are assumed by EC2 instances, ECS tasks, or Lambda via trust policies. GCP: service accounts ARE the identity — a Cloud Run service runs as a service account, no separate role assumption step. Workload Identity (GKE) lets a Kubernetes service account impersonate a GCP service account — same pattern, no key files needed.

**`account_id` constraints**
Must be 6-30 characters, lowercase letters, digits, and hyphens. Must start with a letter. The module constructs IDs as `{project}-{env}-{key}` — keep keys short.

**Custom role ID constraints**
Role IDs can only contain letters, numbers, underscores, and periods (no hyphens). The module replaces hyphens with underscores automatically. IDs are scoped to the project: `projects/{project}/roles/{role_id}`.

**Distributed IAM pattern**
This module holds only account-level resources shared across services. Each service module (GCS, Pub/Sub, Cloud Run) holds its own IAM bindings for that resource — same pattern as awslab. This keeps module blast radius small and avoids circular dependencies.

**`google_project_iam_member` vs `google_project_iam_binding`**
`iam_member` adds a member to a role — additive, never removes others. `iam_binding` is authoritative — it replaces all members for that role. Use `iam_member` for shared environments where multiple Terraform modules manage the same project. `iam_binding` is fine when one module owns the entire role.

## Apply order

```
live/{env}/iam/             # no dependencies — apply first
live/{env}/gcs/             # references service_account_emails output
live/{env}/pubsub/          # references service_account_emails output
live/{env}/artifact-registry/ # references service_account_emails output
live/{env}/secret-manager/  # references service_account_emails output
live/{env}/cloudrun/        # references service_account_emails output
```

## MiniSky notes

- `google_service_account` applies cleanly
- `google_project_iam_custom_role` applies cleanly
- `google_project_iam_member` applies cleanly
- IAM is not enforced in MiniSky — resources are created but access checks are skipped
- `account_id` format validation is enforced by the Terraform provider even against MiniSky
