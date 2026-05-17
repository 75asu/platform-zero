# modules/vpc

Three-tier VPC: public (ALB/NAT), private (ECS/EC2), and data (RDS/ElastiCache) subnets across multiple AZs with fully isolated route tables and a locked-down default security group.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `aws_vpc` | The VPC with DNS hostnames and DNS support |
| `aws_internet_gateway` | Internet access for the public tier |
| `aws_subnet.public[]` | One per AZ — ALB and NAT gateway placement |
| `aws_subnet.private[]` | One per AZ — ECS tasks and EC2 app tier |
| `aws_subnet.data[]` | One per AZ — RDS and ElastiCache, no internet route |
| `aws_eip.nat[]` | Elastic IPs for NAT gateways (when enabled) |
| `aws_nat_gateway.this[]` | Outbound-only internet for private tier (when enabled) |
| `aws_route_table.public` | Default route → internet gateway |
| `aws_route_table.private[]` | Default route → NAT gateway (or none in Ministack) |
| `aws_route_table.data[]` | Local routes only — no internet egress |
| `aws_default_security_group.default` | Locked down — all inbound and outbound rules removed |
| `aws_flow_log` | VPC traffic logs to CloudWatch (conditional) |
| `aws_cloudwatch_log_group` | Destination for flow logs (conditional) |
| `aws_iam_role` + `aws_iam_role_policy` | Permissions for flow log delivery (conditional) |

## Key concepts

**Three-tier isolation**
The public tier is the only one with an internet gateway route. Private tier reaches the internet through NAT (outbound only). The data tier has no internet route at all — RDS and ElastiCache are reachable only from within the VPC. This prevents accidental database exposure and limits blast radius.

**Route table per AZ for private and data tiers**
Each private and data subnet gets its own route table. This is required when using per-AZ NAT gateways so that traffic from a given AZ stays in that AZ (reduces cross-AZ data transfer costs). Even with `single_nat_gateway = true`, separate route tables mean the switch to per-AZ NAT in prod is a one-line change.

**Default security group lockdown**
AWS creates a default security group that allows all inbound traffic from members of the same group and all outbound traffic. This module removes all rules from it. Any resource that ends up in the default SG (e.g., a mis-configured RDS) gets no network access — fail-safe rather than fail-open.

**Kubernetes subnet tagging**
Public subnets are tagged `kubernetes.io/role/elb = 1` and private subnets `kubernetes.io/role/internal-elb = 1`. These tags are required for the AWS Load Balancer Controller to discover subnets when provisioning ALBs or NLBs for EKS services. Harmless when not running EKS.

**NAT gateway**
Disabled by default for Ministack (`enable_nat_gateway = false`) — Ministack does not support it. In real AWS, set `enable_nat_gateway = true`. Use `single_nat_gateway = true` in dev/staging to save cost (single point of failure is acceptable). Use `single_nat_gateway = false` in prod for AZ redundancy.

**VPC flow logs**
When `enable_flow_logs = true`, all accepted and rejected traffic is published to CloudWatch Logs. Use for security auditing, anomaly detection, and cost analysis of cross-AZ traffic. Disabled by default in lab (avoids CloudWatch costs). Enable in staging and prod.

## Architecture

```
                    Internet
                       │
              ┌────────▼────────┐
              │  Internet GW     │
              └────────┬────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
   us-east-1a     us-east-1b     (add AZs)
        │              │
  ┌─────▼─────┐  ┌─────▼─────┐
  │  public   │  │  public   │   10.x.1.0/24, 10.x.2.0/24
  │  subnet   │  │  subnet   │   ALB, NAT GW
  └─────┬─────┘  └─────┬─────┘
        │ NAT           │ NAT
  ┌─────▼─────┐  ┌─────▼─────┐
  │  private  │  │  private  │   10.x.11.0/24, 10.x.12.0/24
  │  subnet   │  │  subnet   │   ECS tasks, EC2
  └─────┬─────┘  └─────┬─────┘
        │ local         │ local
  ┌─────▼─────┐  ┌─────▼─────┐
  │   data    │  │   data    │   10.x.21.0/24, 10.x.22.0/24
  │  subnet   │  │  subnet   │   RDS, ElastiCache
  └───────────┘  └───────────┘
```

## Apply order

```
live/{env}/vpc/     # no dependencies — apply first
live/{env}/rds/     # depends on data_subnet_ids
live/{env}/ec2/     # depends on private_subnet_ids
live/{env}/ecs/     # depends on private_subnet_ids
```

## Ministack notes

- `aws_vpc`, `aws_subnet`, `aws_route_table`, `aws_internet_gateway` all work in Ministack
- `aws_nat_gateway`: **not supported** — set `enable_nat_gateway = false`
- `aws_default_security_group` lockdown applies correctly
- `aws_flow_log`: supported (CloudWatch logging works) — disabled by default to keep lab clean
- CIDR planning: dev uses `10.0.0.0/16`, staging uses `10.1.0.0/16` to keep state isolated per Ministack account

## CIDR conventions in this repo

| Environment | VPC CIDR | Public | Private | Data |
|-------------|----------|--------|---------|------|
| dev | 10.0.0.0/16 | 10.0.1-2.0/24 | 10.0.11-12.0/24 | 10.0.21-22.0/24 |
| staging | 10.1.0.0/16 | 10.1.1-2.0/24 | 10.1.11-12.0/24 | 10.1.21-22.0/24 |
| prod | 10.2.0.0/16 | 10.2.1-2.0/24 | 10.2.11-12.0/24 | 10.2.21-22.0/24 |
