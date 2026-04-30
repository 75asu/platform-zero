# awslab

A self-contained AWS practice lab that runs on a homelab machine. No real AWS account needed - everything runs locally via [Ministack](https://ministack.dev) (LocalStack-compatible) and MinIO for remote state.

## What's built

| Module | What it creates |
|--------|----------------|
| `iam` | Permission boundary, GitHub OIDC provider, CI deploy role, cross-account role |
| `s3` | Encrypted + versioned buckets with lifecycle rules and access logging |
| `ec2` | Instance with SSM access (no SSH), IMDSv2, instance profile, CloudWatch agent |

Two environments: **dev** and **staging**, each isolated via Terragrunt.

## Stack

Terraform + Terragrunt + Ministack + MinIO + Ansible + Docker

## How to run

**Prerequisites:** Docker on a Linux homelab machine. Ansible + Terragrunt on your local machine.

```bash
cp .env.example .env
# fill in TARGET_HOST, TARGET_USER, SSH_KEY_PATH

make up          # installs Ministack + MinIO on homelab
source env.sh    # points AWS CLI and Terraform at Ministack

make tf-dev      # apply all dev modules
make tf-staging  # apply all staging modules
make tf-all      # both at once

make down        # stop and remove all containers
```

## Design notes

**Distributed IAM** - each service module owns its own IAM. The central `iam` module only holds account-level resources: permission boundary, OIDC provider, CI role. Avoids circular dependencies and keeps module boundaries clean.

**Permission boundary** - applied to every role in every service module. Even `AdministratorAccess` can't exceed it. Passed from IAM module output via live config.

**Ministack limitation** - `PutRolePermissionsBoundary` isn't implemented, so `enable_permission_boundary = false` in live configs. All other IAM resources work fine. Module code is written for real AWS - only live configs carry the workaround flag.
