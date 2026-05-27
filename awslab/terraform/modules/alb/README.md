# modules/alb

Internet-facing Application Load Balancer with paired security groups for ALB and ECS tasks, a target group (IP type for awsvpc), and an HTTP listener.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `aws_security_group.alb` | ALB SG: inbound port 80 from internet, outbound to ECS SG only |
| `aws_security_group.ecs` | ECS tasks SG: inbound from ALB SG on container port only, all outbound |
| `aws_security_group_rule.ecs_ingress_from_alb` | Adds ingress rule after both SGs exist (avoids circular reference) |
| `aws_lb` | Internet-facing ALB in public subnets |
| `aws_lb_target_group` | IP-type target group for awsvpc ECS tasks |
| `aws_lb_listener` | HTTP port 80 → forward to target group |

## Key concepts

**Why a separate ALB module (not embedded in ECS)**
The ECS service needs the target group ARN and the ECS security group ID — both ALB module outputs. The ALB security group needs to reference the ECS security group. Keeping ALB separate breaks the circular dependency cleanly: ALB module creates both SGs, ECS module consumes the outputs.

**Security group pairing**
ALB and ECS tasks use paired security groups with SG-to-SG rules instead of CIDR ranges. This means:
- Only traffic routed through *this specific ALB* can reach ECS tasks — not any host in the VPC CIDR
- If the ALB SG is compromised, the blast radius is limited to the ECS SG boundary
- Adding a second ALB (canary, internal) requires explicit SG rule additions — no accidental access

**Circular SG reference pattern**
Both SGs reference each other (ALB egress → ECS, ECS ingress ← ALB). Terraform cannot create these in a single SG definition. Solution: create ECS SG with only egress rules, create ALB SG referencing ECS SG, then add ECS ingress as a separate `aws_security_group_rule`. Terraform resolves this dependency graph correctly in one apply.

**IP target type**
ECS `awsvpc` network mode gives each task its own ENI and IP address. The target group must use `target_type = "ip"` so ECS registers task IPs directly. With `instance` target type (for bridge mode), ECS registers the EC2 host IP — irrelevant with awsvpc.

**Deregistration delay**
When a task is replaced (rolling deploy or scale-in), the ALB keeps sending requests to it for `deregistration_delay` seconds while in-flight connections finish. Too short → request failures mid-deploy. Too long → slow deployments. 30s is a sensible default; reduce for stateless services, increase if tasks handle long-running requests.

**Real AWS additions (not in this module)**
- HTTPS listener on port 443 with ACM certificate
- HTTP → HTTPS redirect on port 80 (replace forward action with redirect)
- Access logs to S3 (`access_logs` block on the ALB)
- Deletion protection (`enable_deletion_protection = true`)
- WAF association via `waf` module's `alb_arn` input

## Apply order

```
live/{env}/vpc/    # public_subnet_ids, vpc_id
live/{env}/alb/    # target_group_arn → ecs, alb_arn → waf, dns_name → route53
live/{env}/ecs/    # consumes target_group_arn + ecs_sg_id
live/{env}/waf/    # consumes alb_arn for web ACL association
live/{env}/route53/ # consumes alb_dns_name for A/CNAME record
```

## Ministack notes

- All resources apply cleanly — verified by live API test
- `aws_lb` returns a real DNS name (`*.elb.amazonaws.com` format)
- `aws_lb_target_group` with `target_type = "ip"` works correctly
- `aws_lb_listener` port 80 forward applies
- SG-to-SG rules work in Ministack
- WAF association (in `waf` module) is accepted
- Route53 CNAME pointing at ALB DNS name resolves within Ministack's DNS
