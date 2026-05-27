# modules/cloudrun

Cloud Run v2 service with configurable scaling, resource limits, env vars, service account identity, and optional public IAM binding. GCP equivalent of awslab/ecs.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `google_cloud_run_v2_service` | The fully managed container service |
| `google_cloud_run_v2_service_iam_member` | Grants `roles/run.invoker` to `allUsers` when `allow_unauthenticated = true` |

## Key concepts

**Cross-cloud comparison: ECS vs Cloud Run**
ECS: you manage cluster capacity (EC2 instances), task definitions are versioned immutable specs, networking is VPC-native with security groups. Cloud Run: fully serverless — no cluster to manage, scales to zero by default, public HTTPS endpoint provisioned automatically (no ALB/Route53 needed), scales to instances not tasks.

**Scale to zero**
`min_instances = 0`: Cloud Run shuts down all instances when there is no traffic. Cold start adds latency to the first request (container pull + init). `min_instances = 1`: always-warm, no cold start penalty, costs more. For dev: scale to zero. For staging/prod with latency SLOs: keep at least 1 warm.

**Identity**
`service_account_email`: the service account the container runs as. Used to authenticate calls to other GCP services (GCS, Secret Manager, Pub/Sub). If empty, Cloud Run uses the default Compute service account (has broad project-level permissions — avoid in prod).

**Authentication**
`allow_unauthenticated = true`: Cloud Run grants `roles/run.invoker` to `allUsers` — the endpoint is publicly accessible. `allow_unauthenticated = false`: callers must present a Google ID token. Service-to-service: the calling service fetches a token via the metadata server and sets it as `Authorization: Bearer`.

**Cloud SQL integration**
Cloud Run has a built-in Cloud SQL Proxy. Add the instance connection name as an annotation and mount the socket via the Cloud Run sidecar. This module does not configure Cloud SQL — wire it via `env_vars` (connection name) and the Cloud Run service annotation outside Terraform or by extending the template.

**Revisions**
Every deployment creates a new revision. Cloud Run keeps old revisions for rollback. Traffic can be split across revisions (`traffic` block in the service) — useful for canary deployments.

## Apply order

```
live/{env}/iam/               # service account email
live/{env}/artifact-registry/ # registry URL for image
live/{env}/cloudrun/          # depends on iam + artifact-registry
```

## MiniSky notes

- `google_cloud_run_v2_service` applies cleanly
- Service URL is returned (MiniSky placeholder, not a real endpoint)
- `latest_ready_revision` output is populated after apply
- `allow_unauthenticated = true` IAM binding applies cleanly
- Actual HTTP routing and request handling is not emulated by MiniSky
