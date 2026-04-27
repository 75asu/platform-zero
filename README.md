# platform-zero

> Practice lab for building production-grade infrastructure from scratch.
> The goal: go from nothing to a fully working platform using the same tools and patterns companies run at scale — no shortcuts, no managed services doing the hard parts for you.

If platform-zero is running, everything in it was built by hand and is working correctly.
If you want to practice what happens when it breaks, that's [sre-dojo](https://github.com/75asu/sre-dojo).

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

Production-level AWS infrastructure built with Terraform and Terragrunt.
Runs against Ministack on the homelab — same Terraform, same patterns, no cloud bill.

```bash
cd awslab
make up      # start Ministack on homelab → ready for Terraform
make down    # destroy all resources, homelab is clean
```

| Layer | Stack |
|-------|-------|
| Fake AWS | Ministack (local AWS API emulator) |
| IaC | Terraform modules + Terragrunt for multi-env |
| Provisioned | VPC, IAM, S3, RDS (in progress) |

---

## Architecture — k8slab

```
                        ┌─────────────────────────────────────────┐
                        │              k3s cluster                 │
                        │                                          │
  git push ────────────▶│  Gitea  ◀──── ArgoCD (app-of-apps)      │
                        │                      │                   │
                        │              ┌───────┴────────┐          │
                        │              │                │          │
                        │           infra layer      apps layer    │
                        │         Vault + ESO      monitoring      │
                        │                          cloudflared     │
                        │                          act-runner      │
                        └─────────────────────────────────────────┘
                                         │
                        Cloudflare Tunnel │ (outbound only)
                                         ▼
                              *.yourdomain.com
```

**GitOps loop:** Every manifest change goes through `make push` → Gitea → ArgoCD reconciles. `kubectl apply` is never used after bootstrap.

**Secret flow:**
```
.env → bootstrap → Vault KV v2
                       │
                   ESO ClusterSecretStore
                       │
               ExternalSecret (in Git)
                       │
               K8s Secret (in cluster, never in Git)
                       │
                   application
```

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
| 4 — Warden | Container provisioning engine (Go + gRPC + Linux primitives) | planned |
| 5 — SLI/SLO | Error budget tracking, burn rate alerts | planned |
| 6 — Chaos | Chaos Mesh experiments against Warden | planned |

## Build phases — awslab

| Phase | What gets built | Status |
|-------|----------------|--------|
| 1 — Ministack | Local AWS API on homelab via Ansible | done |
| 2 — VPC | Subnets, route tables, security groups via Terraform | in progress |
| 3 — IAM | Roles, policies, cross-account access | planned |
| 4 — S3 + RDS | Object storage, managed PostgreSQL | planned |
| 5 — Terragrunt | Multi-env wiring (dev/staging) | planned |
| 6 — Pulumi | VPC scenario in Pulumi for comparison | planned |

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
