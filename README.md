# platform-zero

> One command to go from a blank Linux machine to a production-grade SRE platform.  
> One command to tear it all down.

```bash
make up      # blank machine → full platform (~10 min)
make down    # full teardown, machine is clean
```

No cloud account. No managed services. Just a Linux machine with SSH access.

---

## What this is

A self-contained SRE platform built on bare-metal k3s — designed to demonstrate production patterns that typically require a cloud provider or a team.

Every component is real: not a tutorial toy, not a hello-world demo. The same patterns used at companies running Kubernetes at scale, collapsed into a single-node homelab.

| Layer | Stack |
|-------|-------|
| Cluster | k3s (via k3d), single-node |
| GitOps | ArgoCD app-of-apps, self-hosted Gitea backend |
| Secret management | HashiCorp Vault + External Secrets Operator |
| Networking | Cloudflare Tunnel (zero inbound ports) |
| Observability | Prometheus + Thanos + Grafana + Loki + Tempo |
| CI/CD | Gitea Actions + self-hosted act runner |
| Policy | Kyverno admission controller |
| Tracing | OpenTelemetry Collector → Tempo |
| SLI/SLO | PrometheusRules + error budget burn alerts |
| Workload | Warden — container provisioning engine in Go |
| Operator | WardenRuntime CRD + controller-runtime reconciler |
| Chaos | Chaos Mesh experiments against Warden |

---

## Architecture

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
                        │                          warden          │
                        └─────────────────────────────────────────┘
                                         │
                        Cloudflare Tunnel │ (outbound only)
                                         ▼
                              *.yourdomain.com
```

**GitOps loop:** Every change goes through `git push`. ArgoCD detects the diff in Gitea and reconciles. `kubectl apply` is never used after bootstrap.

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

## Deployment layers

The repo is split into two layers that deploy in order:

```
cluster/
  infra/          ← Vault, ESO — must be healthy before apps start
  apps/           ← everything else — monitoring, runners, workloads
  base/           ← raw K8s manifests referenced by apps/ Applications
```

ArgoCD syncs `infra/` at wave 0 and `apps/` at wave 1. The structure communicates the ordering — no need to read manifests to understand the sequence.

---

## Secret management

Vault is treated as a pre-existing external service — the same pattern as AWS Secrets Manager or HashiCorp Cloud Vault in production. The cluster connects to it but doesn't manage its lifecycle.

Bootstrap handles the imperative work a managed service would otherwise handle:
- `vault operator init` — generates unseal key + root token, saves to `.env`
- `vault operator unseal` — unseals on startup via K8s Secret mount
- Seeds all credentials from `.env` into Vault KV v2 paths

From that point, ArgoCD manages ESO, and ESO creates all K8s Secrets by reading from Vault. Nothing is hardcoded in Git.

| Vault path | What it holds | Consumed by |
|------------|--------------|-------------|
| `secret/gitea` | admin credentials | reference |
| `secret/argocd` | admin password | reference |
| `secret/act-runner` | registration token | ExternalSecret → act-runner-token |
| `secret/minio` | access + secret key | ExternalSecret → minio-credentials, thanos-objstore-secret |
| `secret/grafana` | admin credentials | ExternalSecret → grafana-admin-secret |
| `secret/cloudflare` | tunnel credentials JSON | ExternalSecret → cloudflared-credentials |

---

## CI/CD pipeline

How a Warden code change goes from editor to running in the cluster:

```
1. git push to GitHub (source code only — no images, no secrets)
2. GitHub Actions workflow triggers
3. Job picked up by act runner (pod inside k3s — no tunnel needed)
4. Runner builds + tests: go build ./... && go test ./...
5. Runner pushes image to Gitea OCI registry (internal network)
6. ArgoCD Image Updater detects new tag, commits manifest update to Gitea
7. ArgoCD syncs → rolling update of Warden DaemonSet
```

GitHub never touches an image. Images never leave the cluster network. No GitHub Actions minutes consumed (self-hosted runner).

---

## Prerequisites

**Your machine:**
```bash
brew install ansible kubectl helm
```

**Target machine:**
- Linux (Ubuntu 22.04+)
- 2+ CPU cores, 8GB+ RAM, 40GB+ disk
- SSH access from your machine

**Optional:**
- Cloudflare account + domain (for `*.yourdomain.com` access via tunnel)

---

## Quick start

```bash
git clone https://github.com/75asu/platform-zero
cd platform-zero

cp .env.example .env
# fill in: TARGET_HOST, TARGET_USER, SSH_KEY_PATH, SERVER_IP,
#          GITEA_ADMIN_EMAIL, GIT_USER_NAME, GIT_USER_EMAIL
# optional: CLOUDFLARE_API_TOKEN, CLOUDFLARE_DOMAIN

make up
```

Bootstrap writes all generated credentials (Gitea password, ArgoCD password, Vault tokens, MinIO keys) to `.env` automatically. You don't set them — you read them after `make up`.

---

## Repository structure

```
platform-zero/
├── Makefile                    ← make up / make down / make status
├── .env.example                ← copy to .env, fill in target machine details
│
├── ansible/
│   ├── site.yaml               ← installs k3d + creates cluster (remote)
│   ├── bootstrap.yaml          ← Gitea, ArgoCD, Vault, secrets seeding (local)
│   ├── activate.yaml           ← pushes manifests to Gitea, applies root-app
│   ├── teardown.yaml           ← k3s-uninstall.sh
│   ├── roles/k3s/              ← k3d install role
│   └── files/
│       ├── namespaces.yaml     ← bootstrap namespaces
│       └── root-app.yaml       ← ArgoCD App of Apps (applied once)
│
└── cluster/
    ├── infra.yaml              ← wave 0: deploys cluster/infra/
    ├── apps.yaml               ← wave 1: deploys cluster/apps/
    ├── infra/
    │   ├── vault/app.yaml      ← Vault Helm (drift detection)
    │   └── eso/
    │       ├── app.yaml        ← ESO Helm
    │       └── clustersecretstore-app.yaml  ← ClusterSecretStore (after ESO healthy)
    ├── apps/
    │   ├── cloudflared/        ← Cloudflare Tunnel
    │   ├── act-runner/         ← Gitea Actions self-hosted runner
    │   └── monitoring/         ← Prometheus, Thanos, Grafana, Loki, Tempo, MinIO
    └── base/
        ├── eso/                ← ClusterSecretStore manifest
        ├── cloudflared/        ← Deployment + ExternalSecret
        ├── act-runner/         ← ExternalSecret
        └── monitoring/         ← ExternalSecrets (minio, thanos, grafana)
```

---

## Build phases

| Phase | What gets built | Status |
|-------|----------------|--------|
| 1 — Cluster backbone | k3s, ArgoCD, Gitea, GitOps loop | done |
| 1.5 — CI/CD pipeline | act runner, Gitea OCI registry, Image Updater | done |
| 1.6 — Secret management | Vault + ESO, all secrets through Vault | done |
| 1.7 — Networking | Traefik, cert-manager, Linkerd service mesh | planned |
| 2 — Observability | Prometheus, Thanos, Grafana, Loki, Tempo | in progress |
| 3 — Policy | Kyverno admission controller | planned |
| 4 — Warden | Container provisioning engine (Go + gRPC + Linux primitives) | planned |
| 5 — SLI/SLO | Error budget tracking, burn rate alerts | planned |
| 6 — Chaos | Chaos Mesh experiments against Warden | planned |

---

## Design decisions

**Why self-hosted Gitea instead of pointing ArgoCD at GitHub?**  
The cluster needs a Git remote it can reach internally. GitHub works for source code but the ArgoCD app-of-apps pattern requires the cluster to pull manifests on every sync — adding a round-trip to GitHub for every reconciliation. Gitea runs inside the cluster, zero latency, zero dependency on external network for operations.

**Why Vault bootstrapped by Ansible instead of managed by ArgoCD?**  
Vault requires imperative initialisation — `vault operator init` runs once, generates keys that must be stored, and `vault operator unseal` must run before any secret can be read. This is stateful work that doesn't fit in a Helm values file or a GitOps manifest. Once initialised, ArgoCD takes ownership of the Helm release for ongoing lifecycle.

**Why Cloudflare Tunnel instead of NodePort / LoadBalancer?**  
The homelab machine is on a home network — no public IP, no open inbound ports. cloudflared makes an outbound connection to Cloudflare's edge. Services become reachable at `*.yourdomain.com` without touching the router or opening firewall rules.

**Why k3d instead of a bare k3s install?**  
k3d wraps k3s in Docker containers, which makes teardown deterministic (`k3d cluster delete` removes everything cleanly). Bare k3s leaves systemd units and CNI config behind. For a platform that runs `make down` regularly, clean teardown matters.

---

## What this demonstrates

- **GitOps at the meta-layer** — ArgoCD manages its own app definitions through Gitea, not just workloads
- **Secret management without a cloud provider** — full Vault + ESO setup that mirrors what companies run in production
- **Zero-trust networking** — Cloudflare Tunnel means no inbound ports, no public IP exposure
- **Self-contained CI/CD** — images never leave the cluster network
- **Layered deployment ordering** — infra/apps split with sync-waves, no manual orchestration
- **Operator pattern** — WardenRuntime CRD + controller-runtime reconciler (Phase 4)
- **Systems-level Go** — Linux namespaces, cgroup v2, overlayfs (Phase 4)
- **SLI/SLO engineering** — error budget tracking and multi-window burn alerts (Phase 5)
