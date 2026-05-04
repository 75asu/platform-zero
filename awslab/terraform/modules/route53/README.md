# modules/route53

DNS layer: hosted zone, records, health checks, and query logging in one module.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `aws_route53_zone` | Hosted zone — the DNS container for all records |
| `aws_route53_query_log` | Query logging to CloudWatch — audit every DNS lookup |
| `aws_cloudwatch_log_group` | Destination for query logs with configurable retention |
| `aws_route53_record` | DNS records — A, CNAME, and alias records via for_each map |
| `aws_route53_health_check` | Endpoint health monitoring from Route53's global fleet |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Route53 Hosted Zone                                │
│  binarysquad.org                                    │
│                                                      │
│  ┌──────────────────┐  ┌──────────────────────────┐ │
│  │  Records          │  │  Health Checks            │ │
│  │  www → CNAME ALB   │  │  app → HTTPS :443 /health │ │
│  │  api → Alias ALB   │  │  └─ failure_threshold=3  │ │
│  │  @   → A 1.2.3.4   │  │  └─ request_interval=30  │ │
│  └──────────────────┘  └──────────────────────────┘ │
│           │                        │                 │
│           ▼                        ▼                 │
│  ┌──────────────────────────────────────────────┐   │
│  │  Query Logging → CloudWatch Logs             │   │
│  │  /aws/route53/binarysquad.org                 │   │
│  │  retention: 30 days                           │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

## Key concepts

**Public vs private hosted zones**
Public: resolvable from the internet. Delegated from your domain registrar via NS records. Use for internet-facing services.
Private: only resolvable from VPCs you associate. Not visible from the internet. Use for internal service discovery between VPCs.
Ministack: VPC not supported — use public zones only. The zone is local to Ministack anyway.

**Records: A vs CNAME vs Alias**
`A`: maps a name to an IPv4 address. Works at the zone apex (binarysquad.org).
`CNAME`: maps a name to another domain name. Cannot be used at the zone apex.
`Alias`: AWS-specific, free, works at zone apex. Points to ALB/CloudFront/S3/other Route53 records. Native health check integration. Use instead of CNAME whenever the target is an AWS service.

**Query logging**
Every DNS query hits CloudWatch Logs. Useful for:
- Detecting DNS tunneling (data exfiltration via DNS queries)
- Debugging resolution failures
- Auditing which services are resolving which names

**Health checks**
Route53's global health checker fleet probes your endpoint from multiple regions. Used for:
- Failover routing: redirect traffic away from unhealthy endpoints
- Measuring endpoint latency for latency-based routing
- Non-AWS endpoints (on-prem, third-party APIs)

For ALB-backed services: prefer ALB target group health checks. They're free and per-task instead of per-endpoint. Route53 health checks are for cross-region failover and non-AWS targets.

**TTL strategy**

| TTL | Use case |
|-----|----------|
| 60s | Failover records — fast switch on health check failure |
| 300s | Most A/CNAME records — good balance |
| 3600s | Stable records that rarely change |
| 86400s | MX, TXT, NS records — almost never change |

Lower TTL = more DNS queries to Route53 (cost) but faster propagation on changes.

## Ministack notes

- Public hosted zones work — zone is local to Ministack, not resolvable from real internet
- Records (A, CNAME) work — values resolve within Ministack's DNS
- Alias records: may not resolve in Ministack — use A/CNAME for lab
- Health checks: API calls accepted but actual probing from global fleet is simulated in Ministack
- Query logging: CloudWatch Logs work — logs are local
- Name servers: returned by Ministack but don't resolve externally (local-only zone)

## Real AWS hardening (add these for production)

1. **DNSSEC** — sign the zone to prevent DNS spoofing/cache poisoning
   ```hcl
   resource "aws_route53_key_signing_key" "this" { ... }
   resource "aws_route53_hosted_zone_dnssec" "this" { ... }
   ```
2. **Private hosted zones for internal services** — VPC associations keep internal DNS private
3. **Cross-account delegation** — split zones across accounts (prod zone in prod account, dev in dev)
4. **S3 query log destination** — forward to S3 instead of CloudWatch for long-term retention + Athena queries
5. **IAM restrictions on zone changes** — least-privilege: only CI role can modify records
6. **Multi-region failover** — primary + secondary ALBs in different regions, Route53 failover routing

## Apply order

```
live/{env}/route53/  → no dependencies, can apply first
live/{env}/ecs/      → references route53 zone for ALB alias records
live/{env}/waf/      → references route53 records for web ACL association
```
