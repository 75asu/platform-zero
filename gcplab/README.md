# gcplab

A self-contained GCP practice lab that runs on a homelab machine. No real GCP account needed - everything runs locally via [MiniSky](https://github.com/qamarudeenm/minisky) (GCP API emulator) and MinIO for remote state.

## What's built

Scaffold in place for dev and staging environments. Modules coming: IAM, GCS, Artifact Registry, Cloud Run, Cloud SQL.

## Stack

Terraform + Terragrunt + MiniSky + MinIO + Ansible + Docker

## How to run

**Prerequisites:** Docker on a Linux homelab machine. Ansible + Terragrunt on your local machine.

```bash
cp ../awslab/.env.example .env
# fill in TARGET_HOST, TARGET_USER, SSH_KEY_PATH

make up          # builds MiniSky Docker image + starts MiniSky and MinIO on homelab
source env.sh    # points Terraform at MiniSky + sets fake GCP credentials

make tf-dev      # apply all dev modules
make tf-staging  # apply all staging modules
make tf-all      # both at once

make down        # stop and remove all containers
```

## Design notes

**MiniSky** runs as a Docker container (ubuntu:24.04 base, glibc 2.39+). It emulates 15+ GCP services including Cloud Storage, IAM, Cloud Run, GKE, Cloud SQL, Firestore, and more. Firestore, Spanner, and Datastore spin up real emulator containers on first request.

**GCP project as namespace** - `gcp_project` in `project.hcl` acts like an AWS account ID. Each environment has its own project ID so resources are isolated within MiniSky.

**No state locking** - MinIO doesn't support DynamoDB-style locking. The S3 backend in `root.hcl` intentionally omits `dynamodb_table`. Not an issue for a single-user lab.

**Ministack limitation** - Pub/Sub and BigQuery endpoints are registered in `root.hcl` but not fully emulated by MiniSky. Stick to the services listed in `docs/gcp-services-plan.md` for reliable Terraform apply.
