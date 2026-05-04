# modules/ecs

ECS cluster, service, task definition, ECR repository, CloudWatch log group, ALB (optional), and IAM roles in one module.

## What this module creates

| Resource | Purpose |
|----------|---------|
| `aws_cloudwatch_log_group` | Container log destination — explicit so Terraform owns retention |
| `aws_ecr_repository` | Private image registry — push here, reference in task definition |
| `aws_ecs_cluster` | Logical grouping of services and tasks |
| `aws_ecs_task_definition` | Immutable spec: image, CPU, memory, ports, IAM roles |
| `aws_ecs_service` | Maintains desired_count replicas, handles rolling deploys |
| `aws_lb` | Internet-facing ALB (conditional — skipped in Ministack) |
| `aws_lb_target_group` | ALB target group — IP targets for awsvpc, instance for bridge |
| `aws_lb_listener` | HTTP:80 listener forwarding to target group |
| `aws_iam_role` (x2) | Task execution role (ECS agent) + task role (application) |
| `aws_iam_policy` | Custom policy wiring SQS and Secrets Manager access into task role |

## Key concepts

**Launch type: EC2 vs FARGATE**
EC2: you manage the underlying instances. Containers run via Docker on the EC2 host. Supports bridge and host network modes. Required for Ministack (Docker socket = no Fargate).
FARGATE: serverless — no EC2 instances to manage. AWS provisions compute per task. Requires awsvpc network mode.

**Network mode: bridge vs awsvpc**
`bridge`: Docker bridge networking. Tasks share the EC2 instance's IP. Dynamic host port mapping (ECS picks a free port) — the ALB routes by instance+port. No VPC attachment per task.
`awsvpc`: every task gets its own ENI and private IP. Required for Fargate. ALB routes by IP directly to the task. Enables per-task security groups.

**Execution role vs task role**
Two distinct IAM roles, two distinct principals:
- `execution_role_arn`: used by the ECS **agent** to pull images from ECR and write logs to CloudWatch. Always needed.
- `task_role_arn`: used by the **application process** running inside the container when it calls AWS APIs. Injected as ambient credentials via the ECS metadata endpoint.

Separation = least privilege: the agent can't use app permissions, the app can't pull images using its own role.

**CloudWatch log group**
Created explicitly with a 7-day retention policy. Without this, ECS auto-creates the log group with no retention — logs accumulate indefinitely and cost grows unbounded.

**ALB and target type**
`awsvpc` → target by IP (each task has its own IP). `bridge/host` → target by instance (tasks share the EC2 IP). The module derives `alb_target_type` from `network_mode` automatically.

**Dynamic host port**
`bridge` mode: `hostPort = 0` — ECS assigns a free ephemeral port on the EC2 host. The ALB target group handles routing from port 80 to the dynamic port.
`awsvpc` mode: `hostPort = containerPort` — the task's ENI is directly addressable.

**ECR image tag mutability**
`MUTABLE` in this module — freely overwrite `:latest` in dev/staging. For prod, switch to `IMMUTABLE` to force unique tags (git SHA) and prevent silent rollbacks from overwritten tags.

**Rolling deploys**
`deployment_minimum_healthy_percent = 50`: ECS stops half the old tasks, starts new ones, repeats. 50% is the default — safe for stateless services.
`deployment_maximum_percent = 200`: ECS can temporarily run double the desired count during a deploy. Needs capacity — lower for EC2 clusters with tight headroom.

## Architecture

```
Internet
    │
    ▼
┌───────────────────┐  (create_alb = true, real AWS only)
│  ALB :80          │
│  aws_lb_listener  │
└────────┬──────────┘
         │ forward
         ▼
┌───────────────────┐
│  Target Group     │
│  target_type=ip   │  (awsvpc)
│  target_type=inst │  (bridge)
└────────┬──────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│  ECS Cluster                                            │
│  ┌─────────────────────────────────────────────────┐   │
│  │  ECS Service  (desired_count replicas)          │   │
│  │  ┌──────────────────────────────────────────┐   │   │
│  │  │  Task (container_image, cpu, memory)     │   │   │
│  │  │  ├── execution_role → ECR pull, CW logs  │   │   │
│  │  │  └── task_role → SQS, Secrets Manager    │   │   │
│  │  └──────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
         │ logs
         ▼
┌───────────────────┐
│  CloudWatch Logs  │
│  /ecs/{name}      │
│  retention: 7d    │
└───────────────────┘
```

## Apply order

```
live/{env}/iam/     → task execution and task roles depend on nothing
live/{env}/sqs/     → queue ARNs wired into task role policy
live/{env}/rds/     → secret ARNs wired into task role policy
live/{env}/ecs/     → depends on iam (mock_outputs for plan)
```

## IAM wiring

The task role policy is built from `concat()` — statements are only added when ARNs are provided:

```hcl
sqs_queue_arns  = ["arn:aws:sqs:us-east-1:123456789012:my-queue"]
rds_secret_arns = ["arn:aws:secretsmanager:us-east-1:123456789012:secret:project/env/rds/*"]
```

Empty lists = no policy statement added. The baseline `ECSReadSelf` statement is always included.

## Ministack notes

- `launch_type = "EC2"` — Ministack runs containers via Docker socket, no Fargate
- `network_mode = "bridge"` — no VPC, no ENI allocation
- `create_alb = false` — ALB requires real VPC subnets
- `subnet_ids = []`, `task_security_group_ids = []` — not applicable
- CloudWatch Logs, ECR, ECS service, and task definition all work in Ministack
- ECR `repository_url` will resolve to the Ministack endpoint — push with `docker push` after `docker login`
- Connect to the running container: `docker ps` on the homelab host, then `docker exec -it <id> sh`

## Adding a sidecar container

Extend `container_definitions` in main.tf:

```hcl
container_definitions = jsonencode([
  { name = var.project, image = var.container_image, ... },
  {
    name      = "datadog-agent"
    image     = "datadog/agent:latest"
    essential = false
    environment = [{ name = "DD_API_KEY", value = var.dd_api_key }]
  }
])
```

Non-essential sidecars (essential = false) don't kill the task on crash — the main container keeps running.
