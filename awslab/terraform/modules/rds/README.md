# modules/rds

Managed Postgres instance with a custom parameter group, optional subnet group, and credentials stored in Secrets Manager.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `aws_db_parameter_group` | Custom Postgres config — max_connections, slow query log, DDL logging |
| `aws_db_subnet_group` | Which subnets the instance lives in (conditional — skipped in Ministack) |
| `aws_db_instance` | The Postgres instance itself |
| `aws_secretsmanager_secret` | Secret entry holding connection details |
| `aws_secretsmanager_secret_version` | JSON payload: username, password, host, port, dbname |

## Key concepts

**Custom parameter group**
The default parameter group is shared across all instances of that family and cannot be modified. Creating a custom parameter group gives full control over Postgres config and makes it version-controlled in Terraform. Changing a parameter marked `apply_method = pending-reboot` requires a reboot to take effect — plan for a maintenance window in prod.

**Multi-AZ**
When enabled, RDS maintains a synchronous standby replica in a different AZ. On primary failure, RDS automatically promotes the standby — typically 60-120 seconds. The endpoint DNS flips to the new primary; your application reconnects without config changes. Multi-AZ does not serve read traffic — use read replicas for that.

**Read replicas**
Async replication from the primary. Serve read-heavy traffic (reports, analytics). Replica lag is the tradeoff — reads may see slightly stale data. Promote a replica to a standalone instance for disaster recovery or when splitting the write and read workloads.

**Automated backups and PITR**
`backup_retention_period > 0` enables daily snapshots and transaction log archiving. Point-in-time recovery (PITR) lets you restore to any second within the retention window. Setting `skip_final_snapshot = false` in prod preserves a snapshot on destroy — the last line of defence against `terraform destroy` accidents.

**Encryption at rest**
`storage_encrypted = true` uses KMS (AWS-managed key by default) to encrypt the storage volume, snapshots, and read replicas. Cannot be enabled on an existing unencrypted instance — requires snapshot + restore. Always enable for prod.

**`max_connections`**
RDS sets a default based on instance RAM (roughly `LEAST(DBInstanceClassMemory/9531392, 5000)`). Override in the parameter group when the default is too low (many microservices) or too high (causing OOM under full concurrency). Use RDS Proxy to pool connections so the limit is hit by the proxy, not by hundreds of Lambda/ECS instances.

**Secrets Manager integration**
Apps fetch connection details at startup with `GetSecretValue` — no hardcoded hosts or passwords. The secret JSON matches the standard RDS format recognised by RDS Proxy and most AWS SDK helpers. Grant `secretsmanager:GetSecretValue` on `secret_arn` to the ECS task role or Lambda execution role.

## Apply order

```
live/{env}/rds/    # no dependency on iam or sqs
                   # ECS module (Phase 5) will depend on rds outputs for the secret ARN
```

## Ministack notes

- `aws_db_instance` runs a **real Postgres container** — you can connect and run SQL
- `create_subnet_group = false` — Ministack has no VPC, so the subnet group is skipped
- `storage_encrypted = false` — Ministack has no KMS support
- `performance_insights_enabled = false`, `monitoring_interval = 0` — not supported
- `aws_secretsmanager_secret` works correctly in Ministack
- Connect via: `psql -h 100.64.11.64 -p <port> -U postgres -d app`
  (port is in the `db_endpoint` output)

## Adding a second database

Add `live/{env}/rds-<name>/terragrunt.hcl` pointing to this module with a different `db_name`. Each instance gets its own parameter group and Secrets Manager entry. Share the subnet group by passing the name as an input instead of creating a new one.
