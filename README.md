# platform-zero

> There's enough here to keep you busy for a while.
> Clone it. Break it. Rebuild it. Make it yours.
> All you need is another machine to point it at.

This is a practice lab for infrastructure that actually runs — not diagrams, not tutorials, not "deploy to a managed service and call it done." Production patterns, real tools, a machine you control. The kind of setup you build once, break intentionally, and learn more from than any course.

Fork it. Swap out a component. Add a module. Run the teardown at 2am and bring it back up before breakfast. That's the point.

---

> If platform-zero is running, everything in it was built by hand and is working correctly.

---

## Labs

### `k8slab` — Kubernetes Platform

One command to go from a blank Linux machine to a production-grade SRE platform.
One command to tear it all down.

```bash
cd k8slab
make up      # blank machine → full platform (~10 min)
make down    # full teardown, machine is clean
```

| Layer | Stack |
|-------|-------|
| Cluster | k3s (via k3d), single-node |
| GitOps | ArgoCD app-of-apps, self-hosted Gitea backend |
| Secret management | HashiCorp Vault + External Secrets Operator |
| Networking | Cloudflare Tunnel (zero inbound ports) |
| Observability | Prometheus + Thanos + Grafana + Loki + Tempo |
| CI/CD | Gitea Actions + self-hosted act runner |

### `awslab` — AWS Infrastructure

17 production-pattern Terraform modules across dev and staging. Runs against Ministack on the homelab — same code it would use against real AWS, different endpoint.

```bash
cd awslab
make deploy  # start Ministack on homelab + apply all 17 modules
make reset   # nuke everything and rebuild from scratch
make verify  # smoke test: Ministack, MinIO, DynamoDB lock table
```

| Layer | Stack |
|-------|-------|
| AWS emulator | Ministack (LocalStack-compatible, self-hosted) |
| State | MinIO (S3-compatible, runs on homelab) |
| IaC | Terraform + Terragrunt (multi-env, dependency graph) |
| Provisioned | VPC, IAM, S3, KMS, SQS, RDS, EC2, ALB, ECS, Route53, WAF, CloudFront, ElastiCache, SSM, SNS, Lambda, Scheduler |

---

**GitOps loop:** Every manifest change goes through `make push` → Gitea → ArgoCD reconciles. `kubectl apply` is never used after bootstrap.

No secrets ever touch the Git repository.

---

## Git workflow — k8slab

Two remotes, two purposes — never mixed:

| Remote | Provider | Branch | Purpose |
|--------|----------|--------|---------|
| `origin` | GitHub | `main` | Public portfolio history. Curated commits. Manual push only. |
| `gitea` | Self-hosted Gitea | `cluster` | ArgoCD's Git backend. Operational history. Force-pushed freely. |

```bash
make push       # git push gitea main:cluster --force → ArgoCD syncs within 3 min
make publish    # prompts for confirmation, then git push origin main
```

---

## Build phases — k8slab

| Phase | What gets built | Status |
|-------|----------------|--------|
| 1 — Cluster backbone | k3s, ArgoCD, Gitea, GitOps loop | done |
| 1.5 — CI/CD pipeline | act runner, Gitea OCI registry, Image Updater | done |
| 1.6 — Secret management | Vault + ESO, all secrets through Vault | done |
| 1.7 — IaC lifecycle | Terraform: Vault config, MinIO buckets, Cloudflare tunnel | planned |
| 1.8 — Networking | Traefik, cert-manager, Linkerd service mesh | planned |
| 2 — Observability | Prometheus, Thanos, Grafana, Loki, Tempo | done |
| 3 — Policy | Kyverno admission controller | planned |
| 4 — SLI/SLO | Error budget tracking, burn rate alerts | planned |
| 5 — Chaos | Chaos Mesh experiments | planned |

## Build phases — awslab

| Phase | What gets built | Status |
|-------|----------------|--------|
| 1 | Ministack + MinIO on homelab via Ansible, DynamoDB state lock | done |
| 2 | VPC, IAM, S3, KMS — networking and identity foundation | done |
| 3 | SQS, RDS, EC2, ALB, ECS, Route53, WAF, CloudFront | done |
| 4 | ElastiCache, SSM, SNS, Lambda, EventBridge Scheduler | done |

---

## Prerequisites

**Your machine:**
```bash
brew install ansible kubectl helm awscli
```

**Target machine:**
- Linux (Ubuntu 22.04+)
- 2+ CPU cores, 8GB+ RAM, 40GB+ disk
- SSH access from your machine
- Docker installed

**Optional (k8slab):**
- Cloudflare account + domain (for `*.yourdomain.com` access via tunnel)

---

## Quick start — k8slab

```bash
git clone https://github.com/75asu/platform-zero
cd platform-zero/k8slab

cp .env.example ../.env
# fill in: TARGET_HOST, TARGET_USER, SSH_KEY_PATH, SERVER_IP,
#          GITEA_ADMIN_EMAIL, GIT_USER_NAME, GIT_USER_EMAIL

make up
```

## Quick start — awslab

```bash
cd platform-zero/awslab

# .env already filled in from k8slab setup
make up
source env.sh
aws s3 ls    # confirms Ministack is reachable
```

---

## Repository structure

```
platform-zero/
├── .env                        ← single .env for all labs (gitignored)
├── .gitignore
├── README.md
│
├── k8slab/
│   ├── Makefile                ← make up / make down / make status
│   ├── .env.example
│   ├── ansible/                ← provisions and bootstraps the cluster
│   └── cluster/                ← ArgoCD manifests (GitOps source of truth)
│       ├── infra/              ← wave 0: Vault, ESO
│       └── apps/               ← wave 1: monitoring, runners, workloads
│
└── awslab/
    ├── Makefile                ← make up / make down
    ├── .env.example
    ├── docker-compose.yml      ← Ministack
    ├── env.sh                  ← source to point AWS CLI at homelab
    └── ansible/                ← provisions Ministack on homelab
```
