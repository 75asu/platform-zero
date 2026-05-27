# gcplab

A self-contained GCP practice lab. Runs on any Linux machine you can SSH into — homelab, VPS, or cloud VM. No real GCP account needed. All GCP APIs are served by [MiniSky](https://github.com/qamarudeenm/minisky) (GCP API emulator). Terraform state lives in MinIO.

7 production-pattern Terraform modules across two environments (dev and staging). Every module uses the same code path it would use in real GCP — only the endpoint URLs differ.

---

## Stack

| Component | Role |
|-----------|------|
| MiniSky | GCP API emulator — Cloud Storage, IAM, Pub/Sub, Cloud SQL, Artifact Registry, Secret Manager, Cloud Run |
| MinIO | S3-compatible blob store for Terraform remote state (port 9002, separate from awslab MinIO on 9000) |
| Ansible | Provisions and tears down the lab on the remote machine |
| Terragrunt | Orchestrates module apply order and remote state wiring |
| Docker | Runs MiniSky and MinIO on the target machine |

---

## Prerequisites

**On your local machine:**
- `ansible` — provisions the remote machine
- `terragrunt` — orchestrates Terraform modules
- `terraform` — applied by Terragrunt
- `aws` CLI — used by Make targets for MinIO smoke tests
- `envsubst` — generates the Ansible inventory from the template

**On the target machine:**
- Docker (with the compose plugin)
- SSH access

---

## Quick start

```bash
# 1. Clone the repo and create your config
cp .env.example ../.env
vim ../.env   # fill in TARGET_HOST, TARGET_USER, SSH_KEY_PATH

# 2. Start the lab and apply all modules in one step
make deploy

# 3. Smoke test
make verify
```

`make deploy` builds the MiniSky Docker image, starts MiniSky and MinIO on the target machine, creates the state bucket, then applies all 7 Terraform modules across dev and staging.

---

## Makefile targets

| Target | What it does |
|--------|-------------|
| `make deploy` | `up` + `tf-all` — full fresh install |
| `make up` | Build MiniSky image + start containers via Ansible |
| `make down` | Stop all containers and remove volumes |
| `make teardown` | Alias for `down` |
| `make reset` | `teardown` + `clean` + `deploy` — nuke and rebuild from scratch |
| `make verify` | Smoke test: checks MiniSky health and MinIO state bucket |
| `make tf-all` | Apply all modules in both environments |
| `make tf-dev` | Apply dev environment only |
| `make tf-staging` | Apply staging environment only |
| `make clean` | Delete Terragrunt caches |

---

## Configuration

The lab reads `../.env` (one directory up, at the repo root):

```bash
TARGET_HOST=192.168.1.100   # IP or hostname of your target machine
TARGET_USER=ubuntu           # SSH user
SSH_KEY_PATH=~/.ssh/id_ed25519
```

After `make up`, point your shell at MiniSky:
```bash
source env.sh
curl http://${TARGET_HOST}:8082/healthz   # quick check
```

---

## Modules (7)

| # | Module | What it creates |
|---|--------|----------------|
| 1 | `iam` | Service accounts (app, worker, ci), custom IAM role, project IAM bindings |
| 2 | `gcs` | Versioned Cloud Storage bucket, lifecycle rules, uniform bucket-level IAM |
| 3 | `pubsub` | Pub/Sub topic + DLQ topic, pull subscription + DLQ subscription, publisher and subscriber IAM |
| 4 | `cloudsql` | Postgres 15 instance, database, app user, configurable flags |
| 5 | `artifact-registry` | Docker repository, writer IAM (CI), reader IAM (Cloud Run) |
| 6 | `secret-manager` | Versioned secrets with auto replication, accessor IAM binding |
| 7 | `cloudrun` | Cloud Run v2 service, scaling config, service account identity, optional public IAM |

---

## Cross-cloud comparison (AWS awslab vs GCP gcplab)

| Concept | AWS | GCP |
|---------|-----|-----|
| Object storage | S3 + bucket policy | Cloud Storage + bucket IAM |
| Compute identity | IAM role + trust policy | Service account (no trust policy) |
| Async messaging | SQS + SNS | Pub/Sub (topics + subscriptions) |
| Managed Postgres | RDS | Cloud SQL |
| Container registry | ECR | Artifact Registry |
| Secrets | Secrets Manager + SSM | Secret Manager |
| Serverless containers | ECS on Fargate | Cloud Run v2 |

Both labs use the same Terragrunt module layout. Same pattern, different providers.

---

## Design decisions

**MiniSky as emulator**: runs as a Docker container (ubuntu:24.04 base). All GCP APIs are served on port 8082. The official Google Terraform provider routes each service to MiniSky via `*_custom_endpoint` overrides in `root.hcl`.

**GCP project as namespace**: `gcp_project` in `project.hcl` acts like an AWS account ID. `gcplab-dev` and `gcplab-staging` are isolated namespaces inside MiniSky.

**No state locking**: MinIO does not support DynamoDB-style locking. In real GCP: switch to the `gcs` backend which has built-in object locking.

**`--parallelism 1`**: runs modules sequentially, same as awslab. Avoids the darwin/arm64 hardlink race in the shared Terraform provider cache.

**Distributed IAM**: each service module owns its IAM bindings for that resource. The `iam` module holds only account-level resources (service accounts, custom role). Same pattern as awslab.

---

## MiniSky notes

MiniSky runs as a single Docker container exposing port 8082. All GCP service endpoints are mapped to that port via provider config in `root.hcl`. Two project namespaces are emulated by using different `gcp_project` values (`gcplab-dev` / `gcplab-staging`).

Known limitations vs real GCP:
- IAM is not enforced — resources are created but access checks are skipped
- Cloud SQL: returns a connection_name but actual Postgres connectivity depends on MiniSky version
- Cloud Run: service URL is a placeholder, not a live HTTP endpoint
- Artifact Registry: `docker push` to MiniSky requires additional Docker credential helper setup
- Secret Manager: values stored but not encrypted at rest in MiniSky
