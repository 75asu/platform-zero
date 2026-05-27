# modules/secret-manager

Managed secrets with automatic replication and accessor IAM bindings. GCP equivalent of awslab/ssm SecureString parameters and AWS Secrets Manager combined.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `google_secret_manager_secret` (per entry) | Secret container with replication policy |
| `google_secret_manager_secret_version` (per entry) | The actual secret value (latest version) |
| `google_secret_manager_secret_iam_member` (per entry) | Grants accessor SA `secretmanager.secretAccessor` on each secret |

## Key concepts

**Cross-cloud comparison: SSM / Secrets Manager vs Secret Manager**
AWS splits this into two services: SSM Parameter Store (cheap, no rotation, SecureString = KMS-encrypted) and Secrets Manager (rotation, JSON, higher cost). GCP has one service: Secret Manager. It supports versioned secrets, IAM per secret, audit logs, and is the recommended pattern for all credentials regardless of rotation needs.

**Secret ID naming**
Secret IDs cannot contain slashes — no path hierarchy like SSM. This module names secrets `{project}-{env}-{key}` (e.g., `platform-zero-dev-db-password`). IAM conditions can scope access to secrets matching a prefix pattern.

**Versions**
Every `google_secret_manager_secret_version` creates a new version. Old versions are retained and can be accessed by specifying a version number. The special alias `latest` always refers to the most recent enabled version. Rotate a secret by creating a new version — the old one is not automatically disabled.

**Auto replication vs user-managed replication**
`replication { auto {} }`: GCP manages the replication topology — at least two regions. Simple, no configuration.
`replication { user_managed { replicas { location = "..." } } }`: explicitly specify regions. Use when compliance requires restricting data residency to specific regions, or when you want CMEK encryption per replica.

**Consumer pattern**
Secret Manager does not inject secrets into env vars automatically (unlike SSM/ECS secrets block). In Cloud Run: use the `secrets` block in the service definition to mount secrets as env vars or files. In GKE: use External Secrets Operator (ESO) or the Secret Manager CSI driver to sync secrets into Kubernetes Secrets.

**IAM scoping**
Each secret gets individual IAM. This module grants a single `accessor_service_account` access to all secrets in the module. For finer control — e.g., only the database service can access `db-password` — add `google_secret_manager_secret_iam_member` resources individually outside this module.

## Apply order

```
live/{env}/iam/            # accessor service account email
live/{env}/secret-manager/ # depends on iam
live/{env}/cloudrun/       # consumes secret IDs for env var injection
```

## MiniSky notes

- `google_secret_manager_secret` with `replication { auto {} }` applies cleanly
- `google_secret_manager_secret_version` applies cleanly
- `google_secret_manager_secret_iam_member` applies cleanly
- `AccessSecretVersion` API works — you can read secret values back from MiniSky
- No actual encryption in MiniSky — values stored in plaintext internally
