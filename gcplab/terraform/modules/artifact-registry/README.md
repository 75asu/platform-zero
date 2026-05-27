# modules/artifact-registry

Docker container registry with IAM bindings for push (CI) and pull (Cloud Run / GKE). GCP equivalent of awslab/ecs ECR repository.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `google_artifact_registry_repository` | The Docker format repository in a specific region |
| `google_artifact_registry_repository_iam_member` - writers | Grants `artifactregistry.writer` to CI service accounts (push) |
| `google_artifact_registry_repository_iam_member` - readers | Grants `artifactregistry.reader` to runtime service accounts (pull) |

## Key concepts

**Cross-cloud comparison: ECR vs Artifact Registry**
ECR: regional, per-account, Docker only. Authentication via `aws ecr get-login-password`. Image URIs: `{account}.dkr.ecr.{region}.amazonaws.com/{repo}:{tag}`.
Artifact Registry: regional or multi-region, per-project, supports Docker + NPM + Maven + Python + Go. Authentication via `gcloud auth configure-docker` or `docker credential helper`. Image URIs: `{location}-docker.pkg.dev/{project}/{repo}/{image}:{tag}`.

**Replacing Container Registry**
Artifact Registry replaced the legacy `gcr.io` Container Registry (deprecated). New workloads should use Artifact Registry. Migration path: `docker pull gcr.io/...` → `docker pull {location}-docker.pkg.dev/...`.

**IAM roles**
`roles/artifactregistry.writer`: push images. Used by CI pipelines.
`roles/artifactregistry.reader`: pull images. Used by Cloud Run, GKE node pools, Cloud Build.
`roles/artifactregistry.repoAdmin`: full control. Used for repository management.

**Image tag strategy**
Dev: `:latest` or branch name, mutable. Staging/prod: pinned to git SHA (`:{sha}`) for immutable, auditable deployments. An overwritten `:latest` in prod is a silent rollback — prevent with SHA-based tags.

**Location**
Single region: `us-central1`, `us-east1`, `europe-west1`, etc. Multi-region: `us`, `europe`, `asia`. Multi-region replicates across regions — higher availability, slightly more expensive storage. Use single region to colocate with Cloud Run for lower pull latency.

## Apply order

```
live/{env}/iam/               # CI and app SA emails for IAM bindings
live/{env}/artifact-registry/ # depends on iam
live/{env}/cloudrun/          # consumes docker_registry_url for image URIs
```

## MiniSky notes

- `google_artifact_registry_repository` applies cleanly
- `google_artifact_registry_repository_iam_member` applies cleanly
- `docker_registry_url` output is constructed from inputs — not a live endpoint in MiniSky
- Real `docker push` to MiniSky requires additional configuration not covered here
