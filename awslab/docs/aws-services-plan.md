# AWS Services Build Plan

All modules run against Ministack on the homelab — same Terraform, same patterns,
no cloud bill. Ministack supports 47 services including real Lambda execution,
real RDS (actual Postgres container), real ECS (actual Docker containers),
and real ElastiCache (actual Redis container).

All services verified by live API calls before being added to this plan.

**Architecture goal:** 18 Terraform modules across dev and staging, all workloads
behind the Netbird VPN mesh, state in MinIO, locking in Ministack DynamoDB.

---

## Ministack Support Matrix

| Service | Ministack | Verified | Status |
|---------|-----------|----------|--------|
| S3 | ✅ full | yes | **done** |
| DynamoDB | ✅ full | yes | **done** (state lock only) |
| IAM | ✅ full | yes | **done** |
| SQS | ✅ full | yes | **done** |
| RDS | ✅ full — real Postgres container | yes | **done** |
| ECS | ✅ full — real Docker containers | yes | **done** |
| EC2 | ✅ full | yes | **done** |
| Route53 | ✅ full | yes | **done** |
| WAF | ✅ full | yes | **done** |
| CloudFront | ✅ full | yes | **done** |
| VPC | ✅ full | yes | **done** |
| ALB / ELBv2 | ✅ full | yes | planned — next |
| KMS | ✅ full | yes | planned |
| ElastiCache | ✅ full — real Redis 7 container | yes | planned |
| SSM Parameter Store | ✅ full | yes | planned |
| SNS | ✅ full | yes | planned |
| Lambda | ✅ full — real Python/Node execution | yes | planned |
| EventBridge Scheduler | ✅ full | yes | planned |
| ServiceDiscovery (Cloud Map) | ✅ full | yes | planned |
| Secrets Manager | ✅ full | yes | in use (via RDS module) |
| ECR | ✅ full | yes | in use (via ECS module) |
| CloudWatch Logs | ✅ full | yes | in use (via ECS module) |

---

## Directory Structure

```
terraform/
├── modules/
│   ├── vpc/            ✅ done
│   ├── iam/            ✅ done
│   ├── s3/             ✅ done
│   ├── sqs/            ✅ done
│   ├── rds/            ✅ done
│   ├── ec2/            ✅ done
│   ├── ecs/            ✅ done  (update: ALB target group, Cloud Map)
│   ├── route53/        ✅ done
│   ├── waf/            ✅ done  (update: ALB association)
│   ├── cloudfront/     ✅ done
│   ├── alb/            planned — next
│   ├── kms/            planned
│   ├── elasticache/    planned
│   ├── ssm/            planned
│   ├── sns/            planned
│   ├── lambda/         planned
│   ├── scheduler/      planned
│   └── servicediscovery/ planned
└── live/
    ├── dev/            ✅ all 10 current modules applied
    └── staging/        ✅ all 10 current modules applied
```

---

## Completed Modules (10)

### Module 1 — VPC ✅
Three-tier network: public (ALB/NAT), private (ECS/EC2), data (RDS/ElastiCache).
Isolated route tables per tier. Default SG locked down. Kubernetes ELB subnet tags.
Applied: dev `10.0.0.0/16` · staging `10.1.0.0/16`

### Module 2 — IAM ✅
Roles for ECS task execution, ECS task, EC2 instance, CI deploy.
GitHub OIDC provider for keyless CI. Permission boundary support.
Applied: dev account `000000000000` · staging account `000000000002`

### Module 3 — S3 ✅
App data bucket with versioning, lifecycle rules, and OAC-ready bucket policy
for CloudFront. Block all public access.
Applied: dev · staging

### Module 4 — SQS ✅
Orders queue + DLQ pair. Redrive policy (max 3 receives). Queue policy scoped
to ECS task role. Long polling (20s). Visibility timeout 30s.
Applied: dev · staging

### Module 5 — RDS ✅
Postgres 14, custom parameter group (max_connections, slow query log).
Credentials in Secrets Manager. Optional subnet group and KMS encryption hooks.
Applied: dev `db.t3.micro` · staging `db.t3.micro`

### Module 6 — EC2 ✅
IAM instance role + instance profile. IMDSv2 enforcement hook. Root volume
encryption hook. AMI data source with override for Ministack.
Applied: dev · staging (create_instance = false in Ministack, IAM resources apply)

### Module 7 — ECS ✅
Cluster, ECR repo, task definition, service. CloudWatch log group.
Execution role (pull image, write logs) + task role (app permissions).
Updates pending: ALB target group wiring, Cloud Map service registration.
Applied: dev · staging

### Module 8 — Route53 ✅
Public hosted zone. A/CNAME records. Alias record target for ALB (pending ALB).
Applied: dev · staging

### Module 9 — WAF ✅
WAFv2 REGIONAL web ACL. AWS Managed Rule Sets (Core, Admin Protection,
Known Bad Inputs). Rate limiting. IP allow/block lists. CloudWatch logging.
Update pending: ALB ARN association once ALB module exists.
Applied: dev · staging

### Module 10 — CloudFront ✅
Distribution with S3 OAC origin and optional ALB origin. Managed cache,
origin request, and security response header policies. WAF attachment hook.
Applied: dev · staging

---

## Planned Modules (8)

Build order is fixed by dependencies. Each new module lands in both dev and staging
in the same `terragrunt run --all apply` pass.

---

### Module 11 — ALB (next)

**Why first:** ECS service has no inbound HTTP path. WAF has no REGIONAL target.
Route53 alias record has no destination. ALB unblocks all three.

Resources:
- `aws_lb` — internet-facing application load balancer in public subnets
- `aws_lb_listener` — port 80 listener (redirect to 443 in real AWS)
- `aws_lb_target_group` — targets ECS service (awsvpc network mode, IP type)
- `aws_security_group` — ALB SG: 80/443 from 0.0.0.0, egress to ECS SG
- `aws_security_group` — ECS SG: ingress only from ALB SG

Updates to existing modules:
- `ecs`: wire `load_balancer` block → ALB target group ARN
- `waf`: pass `alb_arn` → `aws_wafv2_web_acl_association`
- `route53`: alias record A → ALB hosted zone + DNS name

Dependencies: vpc (public subnet IDs), waf (web ACL ARN), iam (ECS task SG)

---

### Module 12 — KMS

**Why:** Encryption at rest for ElastiCache, SSM SecureString, and unlocks
`storage_encrypted = true` in RDS and S3 SSE-KMS. Central key management.

Resources:
- `aws_kms_key` — one key per environment, automatic rotation enabled
- `aws_kms_alias` — `alias/platform-zero-{env}`
- `aws_kms_key_policy` — grants to ECS task role, Lambda execution role, RDS

Updates to existing modules:
- `rds`: flip `storage_encrypted = true`, pass `kms_key_id`
- `s3`: add `aws_s3_bucket_server_side_encryption_configuration` with KMS key

Dependencies: iam (role ARNs for key policy grants)

---

### Module 13 — ElastiCache

Redis 7 in the data subnets. Session cache, query result cache, rate-limit
counters, job deduplication store.

Resources:
- `aws_elasticache_subnet_group` — data subnets from VPC module
- `aws_elasticache_cluster` — Redis 7, `cache.t3.micro`, single node in Ministack
- `aws_security_group` — ingress on 6379 from ECS SG + Lambda SG only
- `aws_ssm_parameter` — Redis endpoint published for ECS/Lambda to read

Dependencies: vpc (data subnet IDs), kms (encryption key), ssm (endpoint param)

---

### Module 14 — SSM

Parameter Store for non-secret runtime config: feature flags, service endpoints,
instance counts, ARNs that don't need Secrets Manager.

Resources:
- `aws_ssm_parameter` — String and SecureString parameters per environment
- Parameters: `/platform-zero/{env}/redis/endpoint`, `/platform-zero/{env}/config/*`

ECS task definition updated to read parameters via `secrets` block (SSM → env var
injection at container start — no hardcoded values in task definitions).

Dependencies: kms (SecureString encryption key)

---

### Module 15 — SNS

Fan-out messaging layer. One event published once, consumed by multiple SQS queues.
Decouples producers from consumers.

Resources:
- `aws_sns_topic` — `platform-zero-{env}-orders` topic
- `aws_sns_topic_subscription` — existing SQS orders queue subscribes
- `aws_sns_topic_policy` — ECS task role can publish, SQS can receive

Pattern: ECS service publishes `order.created` to SNS → SNS fans out to:
- existing orders queue (fulfilment worker)
- new analytics queue (Lambda consumer)

Dependencies: sqs (existing queue ARN for subscription)

---

### Module 16 — Lambda

Async workers triggered by SQS, S3 events, and Scheduler. Python 3.12 runtime.
VPC-attached for ElastiCache access.

Resources:
- `aws_lambda_function` — SQS consumer (orders analytics worker)
- `aws_lambda_function` — S3 event processor (object created trigger)
- `aws_lambda_event_source_mapping` — SQS → Lambda (batch size 10)
- `aws_lambda_permission` — allow S3 and Scheduler to invoke
- `aws_security_group` — Lambda SG: egress to RDS SG, ElastiCache SG, internet

Functions:
- `orders-analytics` — reads from SQS analytics queue, writes aggregates to RDS
- `s3-processor` — triggered on S3 object creation, validates and transforms

Dependencies: iam (execution role), sqs (event source), s3 (trigger), vpc (VPC config),
              elasticache (Redis endpoint via SSM), ssm (config parameters)

---

### Module 17 — Scheduler

EventBridge Scheduler for cron jobs. Replaces managing a cron container.
Targets Lambda functions or ECS one-off tasks.

Resources:
- `aws_scheduler_schedule_group` — `platform-zero-{env}`
- `aws_scheduler_schedule` — nightly cleanup job (rate: 1 day)
- `aws_scheduler_schedule` — hourly metrics aggregation (rate: 1 hour)
- `aws_iam_role` — scheduler execution role (lambda:InvokeFunction)

Dependencies: lambda (function ARNs as targets), iam (execution role)

---

### Module 18 — ServiceDiscovery

Cloud Map private DNS namespace. ECS services register themselves on start.
Internal service-to-service calls use DNS (`orders.platform-zero.local`)
instead of hardcoded IPs or SSM lookups.

Resources:
- `aws_service_discovery_private_dns_namespace` — `platform-zero-{env}.local`
- `aws_service_discovery_service` — one entry per ECS service
- ECS service updated: `service_registries` block wired to Cloud Map service

Dependencies: vpc (VPC ID for private namespace), ecs (service update)

---

## Dependency Graph (full 18-module view)

```
vpc ──────────────┬──────────────────────────────────────────┐
                  │                                          │
                  ├── alb ──────┬── ecs (update)            │
                  │             └── waf (update)             │
                  │                 route53 (update)         │
                  │                                          │
                  ├── elasticache ─── ssm ─── ecs (env vars) │
                  │                                          │
                  └── servicediscovery ─── ecs (update)      │
                                                             │
iam ─────────────┬── kms ──────┬── rds (update)             │
                 │             ├── s3 (update)               │
                 │             └── elasticache               │
                 │                                           │
                 └── lambda ───┬── scheduler                 │
                               └── sns ─── sqs (subscription)│
```

---

## Apply order per environment

```
Pass 1 (standalone):  kms, sns, ssm
Pass 2 (needs vpc):   alb, elasticache, servicediscovery
Pass 3 (needs above): lambda, scheduler
Pass 4 (updates):     ecs, waf, route53 re-apply with new inputs
```

In practice, `terragrunt run --all apply` handles the ordering via `dependency {}`
blocks — no manual orchestration needed.

---

## What gets updated (existing modules)

| Module | Change |
|--------|--------|
| `ecs` | ALB target group block, Cloud Map service_registries, SSM secret injection |
| `waf` | Pass `alb_arn` → `aws_wafv2_web_acl_association` (currently null) |
| `route53` | Alias A record → ALB DNS name + hosted zone ID |
| `rds` | `storage_encrypted = true`, `kms_key_id` from KMS module output |
| `s3` | SSE-KMS configuration block with KMS key ARN |

---

## Netbird VPN Coverage

| Layer | Protected by |
|-------|-------------|
| Management plane (Ministack, MinIO, Terraform ops) | Netbird mesh — Tailscale IP only |
| VPC workloads (ECS, RDS, ElastiCache, Lambda in VPC) | Subnet isolation + security groups |
| AWS API services (SSM, SNS, SQS, Scheduler, Lambda invoke) | IAM permissions |
| ALB (internet-facing) | WAF + security groups |
| Phase 5 (pending) | Port bindings locked to Netbird mesh IP, drop 0.0.0.0 |

See: netbird-vpn-plan.md
