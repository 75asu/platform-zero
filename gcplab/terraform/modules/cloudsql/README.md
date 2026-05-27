# modules/cloudsql

Managed Postgres instance with a custom parameter group, application database, and user. GCP equivalent of awslab/rds.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `google_sql_database_instance` | The Postgres instance — machine tier, flags, backup, IP config |
| `google_sql_database` | The application database within the instance |
| `google_sql_user` | Application user with password |

## Key concepts

**Cross-cloud comparison: RDS vs Cloud SQL**
Both are managed Postgres. Key differences:
- RDS uses Secrets Manager for credentials; Cloud SQL has no native Secrets Manager integration — store credentials in Secret Manager manually.
- RDS uses VPC security groups for network access; Cloud SQL uses Authorized Networks and Cloud SQL Proxy.
- Cloud SQL Proxy: a sidecar that handles the TLS tunnel from your app to Cloud SQL. In GKE, it runs as a sidecar container. In Cloud Run, it runs as a built-in sidecar via the `cloud.google.com/cloudsql-instances` annotation.

**Connection patterns**
Public IP (this module, lab only): instance has a public IP, connection over the internet with SSL. Cloud SQL Proxy (recommended): connects via the Cloud SQL API gateway — no public IP needed, no network firewall rules, uses service account authentication. Private IP (prod): instance has a private IP inside your VPC via Private Service Connect — requires VPC peering with `servicenetworking.googleapis.com`.

**Machine tiers**
`db-f1-micro`: 0.6 GB RAM, shared vCPU. For very light dev workloads.
`db-g1-small`: 1.7 GB RAM, shared vCPU. For staging.
`db-n1-standard-*`: dedicated vCPU, production sizing.
`db-custom-*`: custom vCPU and memory.

**`deletion_protection`**
Set `false` for lab — allows `terraform destroy` to delete the instance. Set `true` in prod — prevents accidental deletion via Terraform or the console.

**Database flags**
Cloud SQL maps Postgres config to named flags. `log_min_duration_statement`: logs queries slower than N milliseconds. `max_connections`: override the default (based on instance RAM) when running many microservices.

## Apply order

```
live/{env}/cloudsql/   # no dependencies — connection_name output used by Cloud Run
live/{env}/cloudrun/   # uses connection_name for Cloud SQL Proxy annotation
```

## MiniSky notes

- `google_sql_database_instance` applies and returns a connection_name
- `google_sql_database` and `google_sql_user` apply cleanly
- `deletion_protection = false` is required for `terraform destroy` in lab
- `ipv4_enabled = true` is required in MiniSky (no VPC/private IP support)
- Connect from homelab: `psql -h $(TARGET_HOST) -p <port> -U app -d app`
