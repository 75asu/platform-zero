# awslab

A self-contained AWS practice lab. Runs on any Linux machine you can SSH into — homelab, VPS, or cloud VM. No real AWS account needed. All AWS APIs are served by [Ministack](https://ministack.dev) (LocalStack-compatible). Terraform state lives in MinIO.

17 production-pattern Terraform modules across two environments (dev and staging). Every module uses the same code path it would use in real AWS — only the endpoint URLs differ.

---

## Stack

| Component | Role |
|-----------|------|
| Ministack | AWS API emulator — S3, EC2, ECS, RDS, Lambda, SQS, SNS, SSM, and more |
| MinIO | S3-compatible blob store for Terraform remote state |
| Ansible | Provisions and tears down the lab on the remote machine |
| Terragrunt | Orchestrates module apply order and remote state wiring |
| Docker | Runs all of the above on the target machine |

---

## Prerequisites

**On your local machine:**
- `ansible` — provisions the remote machine
- `terragrunt` — orchestrates Terraform modules
- `terraform` — applied by Terragrunt
- `aws` CLI — used by Make targets for smoke tests and DynamoDB bootstrap
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

That's it. `make deploy` starts Ministack and MinIO on the target machine, bootstraps the state bucket and lock table, then applies all 17 Terraform modules across dev and staging.

---

## Makefile targets

| Target | What it does |
|--------|-------------|
| `make deploy` | `up` + `tf-all` — full fresh install |
| `make up` | Start Ministack + MinIO via Ansible, create DynamoDB lock table |
| `make down` | Stop all containers and remove volumes |
| `make teardown` | Alias for `down` |
| `make reset` | `teardown` + `clean` + `deploy` — nuke and rebuild from scratch |
| `make verify` | Smoke test: checks Ministack, MinIO bucket, and DynamoDB table |
| `make tf-all` | Apply all modules in both environments |
| `make tf-dev` | Apply dev environment only |
| `make tf-staging` | Apply staging environment only |
| `make clean` | Delete Terragrunt caches and Lambda zip artifacts |

### Typical workflows

**First time:**
```bash
make deploy
```

**After pulling changes that touch module source:**
```bash
make clean
make tf-all
```

**Full rebuild from scratch:**
```bash
make reset
```

**Iterating on a single module:**
```bash
cd terraform/live/dev/lambda
terragrunt apply -auto-approve
```

---

## Configuration

The lab reads `../.env` (one directory up, at the repo root):

```bash
TARGET_HOST=192.168.1.100   # IP or hostname of your target machine
TARGET_USER=ubuntu           # SSH user
SSH_KEY_PATH=~/.ssh/id_ed25519
```

This file is gitignored. Copy from `.env.example` to get started.

After `make up`, point your shell at Ministack:
```bash
source env.sh
aws s3 ls   # quick check
```

---

## Modules (17)

| # | Module | What it creates |
|---|--------|----------------|
| 1 | `vpc` | Three-tier network: public (ALB/NAT), private (ECS), data (RDS/ElastiCache). Isolated route tables, locked-down default SG |
| 2 | `iam` | Permission boundary, GitHub OIDC provider, CI deploy role. Central account-level resources only |
| 3 | `s3` | Versioned app bucket, lifecycle rules, OAC-ready policy for CloudFront |
| 4 | `kms` | CMK per environment, auto-rotation, key policy wiring to ECS + Lambda + RDS |
| 5 | `sqs` | Orders queue + DLQ. Redrive policy, long polling, resource policy scoped to ECS task role |
| 6 | `rds` | Postgres 14, custom parameter group, credentials in Secrets Manager |
| 7 | `ec2` | IAM instance profile, IMDSv2 enforcement, CloudWatch agent hook |
| 8 | `alb` | Internet-facing ALB, HTTP listener, IP-type target group for ECS awsvpc, security groups |
| 9 | `ecs` | Cluster, ECR repo, task definition, service. Execution role + task role. ALB wiring |
| 10 | `route53` | Public hosted zone, CNAME to ALB DNS name |
| 11 | `waf` | WAFv2 REGIONAL ACL, AWS Managed Rules, rate limiting, ALB association |
| 12 | `cloudfront` | Distribution with S3 OAC origin, managed cache policies, WAF attachment |
| 13 | `elasticache` | Redis 7 module (disabled in Ministack on Darwin ARM64 — Darwin SIGBUS bug in Docker runtime) |
| 14 | `ssm` | Parameter Store: String + SecureString params under `/platform-zero/{env}/` |
| 15 | `sns` | Fan-out topic. SQS orders queue + Lambda analytics queue both subscribe |
| 16 | `lambda` | `orders-analytics` (SQS consumer) + `s3-processor` (S3 trigger). VPC-attached, archive_file zips |
| 17 | `scheduler` | EventBridge schedule group, nightly-cleanup + hourly-metrics schedules targeting Lambda |

---

Two environments (dev, staging) with separate VPCs and separate Ministack accounts (`000000000000` / `000000000002`).

---

## Design decisions

**Distributed IAM**: each service module owns its IAM resources. The central `iam` module holds only account-level resources (permission boundary, OIDC provider). This avoids circular dependencies and keeps module blast radius small.

**Terragrunt dependency graph**: `dependency {}` blocks in live configs declare the apply order explicitly. `terragrunt run --all` resolves the graph automatically.

**`--parallelism 1`**: runs modules sequentially. Avoids a darwin/arm64 hardlink race in the shared Terraform provider cache that causes intermittent init failures when multiple modules init simultaneously.

**archive_file at plan time**: Lambda handler zips are created by `data.archive_file` during `terraform plan`, not by an external build step. Any change to a `.py` file triggers a function update on the next apply. Generated zips are gitignored.

**`nonsensitive()` on SSM for_each**: Terraform refuses to use a sensitive map as a `for_each` key (keys become resource instance identifiers in state). Parameter names (paths) are not sensitive — only values are. `nonsensitive()` exposes the keys for iteration while values stay sensitive inside each resource.

---

## Ministack notes

Ministack runs as a single Docker container exposing port 4566. All AWS service endpoints are mapped to that port via Terraform provider config in `terraform/live/root.hcl`. Two accounts are emulated by using different `access_key` values (`test` for dev, a different key for staging).

Known limitations vs real AWS:
- ElastiCache: disabled on Darwin ARM64 (SIGBUS in Docker runtime). Module is correct; live config sets `create_cluster = false`.
- CloudWatch CBOR: provider 5.100+ uses binary CBOR encoding. Ministack speaks JSON only. Pinned to `~> 5.99.1`.
- WAF/CloudFront: excluded from `make tf-all` (not supported in Ministack). These modules apply against real AWS.
