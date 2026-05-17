# AWS & Cloud Requirements — JD Analysis

Analysed 31 JDs across Crusoe, ClickHouse, Elastic, PostHog, Railway, Indeed, Meta, Cognition,
Bitrise, Juniper Square, Wikimedia, eBay, Kpler, One2N, Harvey, Rippling, Tavus, Kalshi, Orion Innovation, Tekhqs, and others.

---

## Top Skills by Frequency

| Skill | Frequency | Practisable with local setup? |
|-------|-----------|-------------------------------|
| Kubernetes / EKS | 17/31 roles | Yes — k3d in platform-zero |
| Terraform | 13/31 roles | Yes — Vault + MinIO + MiniStack |
| Observability (Prometheus, Grafana, Datadog) | 10/31 roles | Yes — full stack in platform-zero |
| Multi-account AWS setup | 8/31 roles | Partial — MiniStack supports account IDs |
| VPC / Networking | 8/31 roles | Partial — MiniStack mocks it |
| RDS / PostgreSQL | 7/31 roles | Yes — MiniStack runs real PostgreSQL containers |
| Lambda | 6/31 roles | Yes — MiniStack runs real Lambda |
| IAM | 7/31 roles | Partial — MiniStack responds but doesn't enforce |
| S3 / Object Storage | 7/31 roles | Yes — MiniStack + MinIO both work |
| SQS / Queues | 4/31 roles | Yes — confirmed working in MiniStack |
| SLO / SLI frameworks | 8/31 roles | Yes — platform-zero Phase 5 |
| GitOps / ArgoCD | 5/31 roles | Yes — platform-zero |
| CI/CD pipelines | 6/31 roles | Yes — Gitea Actions in platform-zero |
| EC2 | 5/31 roles | Yes — MiniStack (mocked, Terraform syntax is real) |
| ALB / ELB | 4/31 roles | Partial — MiniStack creates resource, no real routing |
| CloudWatch (logs + alarms) | 6/31 roles | Yes — MiniStack supports log groups and alarms |
| KMS | 4/31 roles | Yes — MiniStack supports key creation and encrypt/decrypt |
| Secrets Manager | 5/31 roles | Yes — MiniStack supports full workflow |
| SSM Parameter Store | 3/31 roles | Yes — MiniStack supports it |
| SNS | 3/31 roles | Yes — MiniStack supports topics and subscriptions |
| OIDC / IRSA (workload identity) | 5/31 roles | Yes — MiniStack IAM OIDC provider + annotated SA |
| OPA / Gatekeeper | 3/31 roles | No — Kubernetes-side only, no MiniStack equivalent |
| VPC peering / Transit Gateway | 3/31 roles | Partial — resource creates, no real routing |
| Keycloak / LDAP | 2/31 roles | No — separate tool, run as Docker container if needed |

---

## AWS Services to Learn (Ranked)

### Must-know (appears in >50% of AWS-heavy roles)
- **EKS** — managed Kubernetes. Terraform: `aws_eks_cluster`, node groups, IRSA roles
- **IAM** — roles, policies, OIDC federation for CI/CD, service account binding
- **VPC** — subnets, security groups, NAT gateway, route tables
- **S3** — buckets, lifecycle policies, bucket policies, versioning
- **RDS** — PostgreSQL instances, subnet groups, parameter groups

### High-value (appears in 30-50% of roles)
- **Lambda** — event-driven functions, IAM execution roles
- **SQS / SNS** — queues, topics, subscriptions, DLQs
- **CloudWatch** — log groups, metric filters, alarms
- **ECR** — image registry, lifecycle policies, image scanning
- **Secrets Manager / SSM Parameter Store** — secret rotation, cross-service access

### Specialist (specific company types)
- **Karpenter** — Kubernetes autoscaling on EKS (PostHog, Kpler)
- **DocumentDB** — ClickHouse specifically
- **Cost Explorer / Budgets** — FinOps roles (Elastic, Kpler, Crusoe)
- **GPU instance types** — ML infra roles (Kpler, Meta)

---

## IaC Tools Ranked
1. **Terraform** — 13 mentions, industry standard
2. **ArgoCD / GitOps** — 5 mentions (you have this)
3. **Ansible** — 5 mentions (you have this)
4. **GitHub/GitLab Actions** — 6 mentions (you have Gitea Actions)
5. **CloudFormation** — 4 mentions (AWS-native, lower priority)
6. **AWS CDK** — 3 mentions (Python/TypeScript, ClickHouse-specific)
7. **Puppet** — 3 mentions (Wikimedia, legacy)

---

## Company Cloud Strategy

| Company | Primary Cloud | Key AWS Services | Notes |
|---------|--------------|-----------------|-------|
| PostHog | AWS | EKS, Karpenter, multi-account | GitOps, Cilium networking |
| Crusoe | AWS | Multi-account, Well-Architected | GPU/ML infra |
| ClickHouse | AWS + multi-cloud | EKS, SQS, Lambda, DocumentDB | CDK preferred over Terraform |
| Indeed | AWS | EKS, Terraform, Datadog | SLO/SLI heavy |
| Kpler | AWS | EKS, GPU instances, cost optimization | ML workloads |
| Juniper Square | AWS | EKS, RDS, Helm, ArgoCD | Multi-region |
| Cognition | AWS preferred | General AWS | Also GCP/Azure acceptable |
| Elastic | Multi-cloud | AWS + GCP + Azure all equal | FinOps, security specialisms |
| Bitrise | GCP | Google Cloud primary | Not AWS |
| Railway | Bare metal | Custom networking | Minimal cloud dependency |
| Meta | Internal | Internal infra, MySQL at scale | No AWS |
| Wikimedia | On-prem | Puppet, Debian, HAProxy | No cloud |
| eBay | Multi-cloud | Cloud-agnostic | Kubernetes focus |

---

## What You Can Practice Locally

### Full practice possible (platform-zero + MiniStack)
- Terraform: S3, IAM roles/policies, SQS, DynamoDB, Secrets Manager, RDS, Lambda
- Kubernetes: EKS patterns (using k3d), RBAC, namespaces, node affinity
- Observability: Prometheus, Grafana, Loki, Tempo — already running
- GitOps: ArgoCD app-of-apps — already running
- CI/CD: Gitea Actions — already running
- Secret management: Vault + ESO — already running

### Partial practice (behaviour differs from real AWS)
- VPC / networking (MiniStack mocks responses but no real network isolation)
- IAM enforcement (policies are not actually enforced in MiniStack)
- Multi-account setups (MiniStack uses access key as account ID trick)
- Karpenter (needs real EKS node groups)

### Needs real AWS (or skip for now)
- EKS cluster provisioning at real scale
- Route53 DNS with real resolution
- CloudFront distributions
- Cost Explorer / Budgets (no usage = no cost data)

---

## Practice Scenario Ideas

### Scenario 1 — Core Terraform workflow (MiniStack)
Build an opinionated AWS "application stack" from scratch with Terraform:
- VPC with public/private subnets, IGW, NAT gateway, route tables, security groups
- EC2 instances in private subnet with IAM instance profile
- ALB in public subnet pointing to EC2 target group
- S3 bucket with versioning, lifecycle policy, and KMS server-side encryption
- IAM role with least-privilege policy and OIDC provider for GitHub Actions (zero-credential CI)
- RDS PostgreSQL instance in private subnet with subnet group
- SQS queue with DLQ and redrive policy
- SNS topic subscribed to SQS
- Secrets Manager secret (encrypted with KMS key)
- SSM Parameter Store entry (for non-secret config)
- KMS key with alias and key rotation enabled
- CloudWatch log group with retention
- CloudWatch metric alarm (CPU > 80% on EC2)
- VPC peering connection (second VPC to peer with)

Goal: understand resource dependencies, state, variable files, outputs, and be able to explain every resource in an interview

### Scenario 2 — EKS + IRSA pattern (k3d + MiniStack)
- Kubernetes ServiceAccount annotated with IAM role ARN
- MiniStack IAM role that allows S3 access
- Pod that reads from S3 using the service account
- This mirrors the real IRSA pattern companies use

Goal: understand how pods authenticate to AWS without static credentials

### Scenario 3 — GitOps Terraform (platform-zero)
- Store Terraform state in MinIO (S3-compatible backend)
- Run Terraform from Gitea Actions CI/CD pipeline
- Changes to `.tf` files trigger plan → manual approval → apply
- This is how companies run Terraform in production (Atlantis pattern)

Goal: understand how Terraform fits into a real workflow, not just local runs

### Scenario 4 — Broken infrastructure diagnosis (sadservers.com)
- Use sadservers.com for Linux + Kubernetes debugging scenarios
- Time yourself — 20 minutes per scenario
- This directly simulates One2N / InfraCloud hands-on rounds

### Scenario 5 — Observability from scratch (MiniStack + platform-zero)
- Deploy a simple Go HTTP service to k3d
- Wire up CloudWatch-style alerting via MiniStack
- Add Prometheus metrics, Loki logs, Tempo traces
- Write SLO rules: availability > 99.9%, p99 latency < 200ms
- This covers the "observability setup" question both companies ask

---

## The Missing Piece — Real Prod Scenario Generation

The gap you identified is real: without a staff/principal engineer creating scenarios, you're self-generating exercises which tend to stay in your comfort zone.

Options to fill this gap:

1. **sadservers.com** — community-built broken Linux/K8s scenarios, closest thing to a real hands-on round
2. **killer.sh** — CKA/CKAD exam simulator, Kubernetes scenario-based, timed
3. **KodeKloud playgrounds** — pre-broken environments across Kubernetes, Terraform, Linux
4. **One2N's own SRE bootcamp content** — they publish case studies and blog posts describing real client problems
5. **Gremlin / Chaos Mesh** — inject real failures into platform-zero and diagnose them (this is Phase 6)

The best combination for your situation:
- sadservers.com for timed Linux/K8s diagnosis (free, no setup)
- killer.sh for Kubernetes specifically (paid but cheap, ~$30)
- Build Scenario 3 and 4 above yourself in platform-zero
