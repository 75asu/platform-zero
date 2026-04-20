# platform-zero

> One command to go from a blank VPS to a full SRE platform.
> One command to tear it all down.

Anyone can clone this repo, fill in `.env`, and run `make up`.
No cloud account needed. No managed services. Just a Linux machine with SSH access.

---

## What this is

A self-contained SRE platform kit that demonstrates production-grade infrastructure patterns:

- **GitOps** — ArgoCD app-of-apps with Gitea as self-hosted Git backend
- **Secret management** — Vault + External Secrets Operator (ESO), seeded by Ansible from .env
- **Networking** — Traefik ingress + cert-manager + Let's Encrypt + Linkerd service mesh
- **Observability** — Prometheus + Thanos + Grafana + Loki + Tempo (full LGTM stack)
- **Distributed tracing** — OpenTelemetry Collector + Tempo
- **Policy as code** — Kyverno admission controller with real policies
- **SLI/SLO** — PrometheusRules, error budget burn alerts, Grafana SLO dashboard
- **Systems-level workload** — Warden: a container provisioning engine in Go (gRPC, Linux namespaces, cgroups, overlayfs)
- **Kubernetes Operator** — WardenRuntime CRD + controller-runtime based controller
- **Self-contained CI/CD** — Gitea Actions + act_runner + Gitea OCI registry + ArgoCD Image Updater
- **Chaos Engineering** — Chaos Mesh experiments against Warden

---

## Gap coverage (why this project exists)

| Skill gap | Tier | Covered by |
|-----------|------|------------|
| ArgoCD | 1 | Core GitOps backbone |
| Secret management (Vault) | 1 | Phase 1.6 — Vault + ESO |
| SLI/SLO/error budgets | 1 | Phase 5 — PrometheusRules + Grafana |
| Kubernetes Operators | 1 | Phase 4b — WardenRuntime CRD + controller |
| Linkerd service mesh | 2 | Phase 1.7 — networking layer |
| cert-manager / Let's Encrypt | 2 | Phase 1.7 — networking layer |
| Kyverno | 2 | Phase 3 — admission policies |
| OpenTelemetry | 2 | Phase 4 — OTEL Collector + Warden instrumentation |
| Distributed tracing | 2 | Phase 2 — Tempo + Grafana |
| gRPC | Partial | Phase 4 — Warden gRPC server |
| OS primitives | Railway | Phase 4 — Warden (namespaces, cgroups, overlayfs) |
| Thanos | InfraCloud | Phase 2 — long-term Prometheus storage |
| Self-hosted CI/CD runners | Luxor depth | Phase 1.5 — Gitea Actions + act_runner |
| Chaos Engineering | InfraCloud | Phase 6 — Chaos Mesh |

---

## Two commands

```bash
make up      # blank VPS → full SRE platform (~10 min)
make down    # full teardown, machine is clean
```

Intermediate targets:
```bash
make cluster   # k3s only (Ansible)
make bootstrap # Gitea + ArgoCD (kubectl apply, once)
make gitops    # push manifests to Gitea, apply root-app
make status    # cluster health + ArgoCD sync status
make restart   # make down && make up
```

---

## Release flow

How a Warden code change goes from your editor to running in the cluster:

```
1. You write code locally
   warden/pkg/namespace/isolation.go

2. git push to GitHub (public repo — source code only, no images)
   github.com/75asu/platform-zero

3. GitHub Actions workflow triggers
   .github/workflows/warden-release.yaml

4. Job is picked up by ARC runner (pod running inside k3s cluster)
   Runner has direct access to the internal network — no tunnels needed.

5. Runner builds and tests
   go build ./...
   go test ./...

6. Runner builds Docker image and pushes to Gitea OCI registry
   docker build -t gitea-svc.gitea.svc.cluster.local:3000/admin/warden:v0.2 .
   docker push gitea-svc.gitea.svc.cluster.local:3000/admin/warden:v0.2

7. ArgoCD Image Updater detects new tag in Gitea registry
   Polls registry → sees warden:v0.2 → updates image tag in manifest
   Commits back to Gitea: cluster/apps/warden/daemonset.yaml

8. ArgoCD detects manifest change in Gitea
   Syncs → rolling update of Warden DaemonSet

9. New Warden version is live
   Prometheus scrapes new metrics, Tempo receives new traces
```

**Why this is fully self-contained:**
- GitHub holds source code only — no images, no secrets
- Images never leave the cluster network
- ARC runner eliminates the need for any external registry
- Gitea serves as both Git remote and OCI registry
- No GitHub Actions minutes consumed (self-hosted runner, unlimited)

**Components involved in the release pipeline:**

| Component | Role |
|-----------|------|
| GitHub | Source code host (public repo) |
| GitHub Actions | Workflow trigger + CI definition |
| ARC (Actions Runner Controller) | Self-hosted runner inside k3s |
| Gitea | Git remote + OCI image registry |
| ArgoCD Image Updater | Watches registry, updates manifest tag |
| ArgoCD | Reconciles manifest → deploys to cluster |

**Warden release versioning:**

| Version | What it does | Release trigger |
|---------|-------------|-----------------|
| v0.1 | Hello world gRPC server | Repo goes public — pipeline is live |
| v0.2 | Real namespace isolation (CLONE_NEWPID, CLONE_NEWNET) | After Phase 1.5 |
| v0.3 | cgroup v2 resource limits | After Phase 5 |
| v0.4 | overlayfs image layers | After Phase 6 |

---

## Prerequisites (on your local machine)

- `ansible` — `brew install ansible`
- `kubectl` — `brew install kubectl`
- `git`
- SSH key with access to the target machine
- `.env` filled in (copy from `.env.example`)

Target machine requirements:
- Linux (Ubuntu 22.04+ recommended)
- 2+ CPU cores, 4GB+ RAM, 20GB+ disk
- SSH access
- Ports 6443, 30080, 30300 accessible from your machine

---

## Configuration

```bash
cp .env.example .env
# edit .env — all credentials and machine-specific values go here
```

`.env` variables:

```bash
TARGET_HOST=            # IP or hostname of your VPS
TARGET_USER=            # SSH user (ubuntu, root, etc.)
SSH_KEY_PATH=~/.ssh/id_ed25519

SERVER_IP=              # IP to embed in kubeconfig (usually same as TARGET_HOST)
ARGOCD_NODEPORT=30080
GITEA_NODEPORT=30300

GITEA_ADMIN_USER=admin
GITEA_ADMIN_PASSWORD=   # choose something strong
GITEA_ADMIN_EMAIL=      # your email

REPO_NAME=platform-zero

# CI/CD — ARC runner registration
GITHUB_PAT=             # GitHub Personal Access Token (repo + workflow scope)
                        # used by ARC to register runners with your GitHub repo
ARC_RUNNER_SCALE=1      # number of runner pods (1 is enough for homelab)
```

Nothing in the codebase has hardcoded IPs, users, or credentials.
Everything reads from `.env`.

---

## Repository structure

```
platform-zero/
│
├── PLAN.md                        ← this file
├── Makefile                       ← make up / make down
├── .env.example                   ← template, committed to git
├── .env                           ← gitignored, user fills in
├── .gitignore
│
├── ansible/                       ← OS layer: k3s only, nothing else
│   ├── ansible.cfg
│   ├── inventory/
│   │   └── hosts.yaml.tpl         ← template, populated from .env by Makefile
│   ├── group_vars/
│   │   └── all.yaml
│   ├── roles/
│   │   └── k3s/
│   │       └── tasks/main.yaml
│   ├── site.yaml                  ← install k3s, write kubeconfig
│   └── teardown.yaml              ← k3s-uninstall.sh
│
├── cluster/                       ← K8s layer: GitOps owns this
│   │
│   ├── bootstrap/                 ← applied manually ONCE, never again
│   │   ├── namespaces.yaml        ← all namespaces upfront
│   │   ├── argocd/
│   │   │   └── install.yaml       ← ArgoCD install manifest
│   │   ├── gitea/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── pvc.yaml
│   │   └── root-app.yaml          ← App of Apps — hands control to ArgoCD
│   │
│   └── apps/                      ← ArgoCD owns this forever
│       ├── monitoring/            ← Phase 2
│       │   ├── prometheus/        ← kube-prometheus-stack Helm chart
│       │   ├── thanos/            ← long-term Prometheus storage
│       │   ├── grafana/           ← dashboards + SLO panels
│       │   ├── loki/              ← log aggregation
│       │   └── tempo/             ← distributed tracing backend
│       ├── otel/                  ← Phase 2
│       │   └── collector/         ← receives traces, routes to Tempo + Prometheus
│       ├── policy/                ← Phase 3
│       │   └── kyverno/           ← Kyverno + policies
│       ├── warden/                ← Phase 4
│       │   ├── crds/              ← WardenRuntime CRD
│       │   ├── controller/        ← operator deployment
│       │   ├── daemonset.yaml     ← Warden runtime (privileged)
│       │   ├── service.yaml       ← gRPC port
│       │   └── servicemonitor.yaml
│       ├── slo/                   ← Phase 5
│       │   ├── prometheusrules.yaml
│       │   └── grafana-dashboard.yaml
│       ├── arc/                   ← Phase 1.5
│       │   └── arc-runner/        ← ARC self-hosted runner (Helm)
│       ├── argocd-image-updater/  ← Phase 1.5
│       │   └── install.yaml       ← ArgoCD Image Updater (watches Gitea OCI)
│       └── chaos/                 ← Phase 6
│           ├── chaos-mesh/        ← Chaos Mesh install
│           └── experiments/       ← chaos experiments against Warden
│
├── .github/
│   └── workflows/
│       └── warden-release.yaml    ← CI: build → test → push image → done
│
└── warden/                        ← Go source code
    ├── cmd/
    │   └── warden/
    │       └── main.go            ← gRPC server entrypoint
    ├── pkg/
    │   ├── namespace/             ← Linux namespace isolation
    │   ├── cgroup/                ← cgroup v2 resource limits
    │   ├── overlay/               ← overlayfs layer mounting
    │   └── server/                ← gRPC server implementation
    ├── proto/
    │   └── warden.proto           ← protobuf service definition
    ├── operator/                  ← WardenRuntime controller
    │   ├── api/v1alpha1/          ← CRD types
    │   └── controllers/           ← reconciler
    ├── Dockerfile
    └── go.mod
```

---

## Build phases

### Phase 1 — Cluster backbone
**Goal:** k3s running, ArgoCD + Gitea deployed, GitOps loop active.
After this phase: `git push` to Gitea = cluster converges.

- [ ] Ansible role: k3s install (disable traefik, servicelb)
- [ ] Ansible role: kubeconfig setup (replace 127.0.0.1 with SERVER_IP)
- [ ] Ansible teardown: k3s-uninstall.sh
- [ ] Bootstrap: namespaces.yaml
- [ ] Bootstrap: Gitea (Deployment + PVC + NodePort Service)
- [ ] Bootstrap: ArgoCD install manifest
- [ ] Bootstrap: root-app.yaml (App of Apps)
- [ ] Makefile: `make up`, `make down`, `make status`
- [ ] .env.example with all variables documented
- [ ] Gitea init script (create admin, create repo, push manifests)

### Phase 1.5 — Self-contained CI/CD pipeline ✓ (done)
**Goal:** Every `git push` to `warden/` builds, tests, pushes image, and deploys automatically.
After this phase: repo goes public, Warden v0.1 is live, pipeline is proven end-to-end.

**Why ARC inside the cluster:**
GitHub Actions jobs run on GitHub's servers by default — they have no network access
to the homelab. ARC (Actions Runner Controller) runs a runner pod inside k3s.
The runner IS inside the cluster, so it can push directly to the Gitea OCI registry
without any tunneling or external exposure.

- [ ] ARC — Helm ArgoCD app (`cluster/apps/arc/`)
  - [ ] GitHub PAT secret (from `.env`) — runner registration
  - [ ] ScaleSet runner targeting `platform-zero` repo
- [ ] ArgoCD Image Updater — Helm ArgoCD app (`cluster/apps/argocd-image-updater/`)
  - [ ] Configured to watch Gitea OCI registry
  - [ ] Write-back to Gitea (updates image tag in manifest, commits)
- [ ] GitHub Actions workflow (`.github/workflows/warden-release.yaml`)
  - [ ] Trigger: push to `warden/**`
  - [ ] Steps: `go build` → `go test` → `docker build` → `docker push` to Gitea OCI
  - [ ] Runs on: self-hosted ARC runner label
- [ ] Warden v0.1 — hello world gRPC server
  - [ ] `proto/warden.proto` — `RunContainer` RPC returning `{message: "hello from warden"}`
  - [ ] `cmd/warden/main.go` — gRPC server listening on `:50051`
  - [ ] `Dockerfile` — distroless base
  - [ ] `cluster/apps/warden/daemonset.yaml` — privileged DaemonSet, image from Gitea OCI
- [ ] **Repo goes public on GitHub at this point**

### Phase 1.6 — Secret management (Vault + ESO)
**Goal:** All secrets stored in self-hosted Vault, synced to cluster via External Secrets Operator. No more imperatively created K8s Secrets in bootstrap.yaml.
After this phase: `ExternalSecret` manifests in Git reference Vault paths. ESO creates K8s Secrets automatically. bootstrap.yaml seeds Vault from `.env` once.

**How seeding works:**
Ansible calls the Vault HTTP API (same `uri` module used for Cloudflare API calls).
Reads values from `.env` via `lookup('env', ...)`, writes to Vault KV paths.
Idempotent — checks if Vault is already initialized before running init + unseal.
Vault root token + unseal keys saved back to `.env` by bootstrap.

- [x] Vault — Helm ArgoCD app (`cluster/infra/vault/`)
  - [x] Raft backend (built-in, no external dependency)
  - [x] K8s auth method enabled (ESO authenticates via ServiceAccount token)
  - [x] Auto-unseal via K8s Secret (unseal key stored as K8s Secret, Vault reads on restart)
- [x] External Secrets Operator (ESO) — Helm ArgoCD app (`cluster/infra/eso/`)
- [x] ClusterSecretStore — points ESO at Vault, uses K8s auth
- [x] bootstrap.yaml: Vault init + unseal + secret seeding via Vault HTTP API
  - [ ] `secret/cloudflare` — api_token, domain, tunnel credentials (deferred — complex JSON blob)
  - [x] `secret/gitea` — admin_password
  - [x] `secret/argocd` — admin_password
  - [x] `secret/act-runner` — registration token
- [x] Migrate existing bootstrap-created secrets to ExternalSecret manifests
  - [x] `cloudflared-credentials` → ExternalSecret (secret/cloudflare in Vault)
  - [ ] `cloudflared-config` → stays as ConfigMap (tunnel ID is not a secret)
  - [x] `act-runner-token` → ExternalSecret (secret/act-runner in Vault)
  - [x] `thanos-objstore-secret` → ExternalSecret (secret/minio in Vault)
  - [x] `minio-credentials` → ExternalSecret (secret/minio in Vault)
- [x] `.env.example` updated with Vault variables (VAULT_ROOT_TOKEN, VAULT_UNSEAL_KEY)

---

### Phase 1.7 — Networking layer (Traefik + cert-manager + Linkerd)
**Goal:** Prod-equivalent networking. Traefik as ingress controller, cert-manager issuing real Let's Encrypt wildcard certs via Cloudflare DNS-01, Linkerd providing mTLS between all services.
After this phase: all services accessible via `*.binarysquad.org` with real TLS. Linkerd golden metrics per service. Cloudflare tunnel routes to Traefik instead of directly to services.

**Architecture:**
```
Internet → Cloudflare edge (TLS) → cloudflared tunnel → Traefik → [Linkerd proxy] → service
```

- [ ] Traefik — Helm ArgoCD app (`cluster/apps/traefik/`)
  - [ ] IngressRoute CRDs for all services (Grafana, ArgoCD, Gitea, Prometheus, Vault)
  - [ ] Update cloudflared config to route all traffic to Traefik (single entry point)
- [ ] cert-manager — Helm ArgoCD app (`cluster/apps/cert-manager/`)
  - [ ] CRDs in sync-wave -1 (before cert-manager itself)
  - [ ] ClusterIssuer: letsencrypt-staging (test first, no rate limits)
  - [ ] ClusterIssuer: letsencrypt-prod (switch after staging validates)
  - [ ] DNS-01 solver via Cloudflare API token (already in Vault)
  - [ ] Certificate: wildcard `*.binarysquad.org`
- [ ] trust-manager — Helm ArgoCD app, distributes CA bundles across namespaces
- [ ] Linkerd — Helm ArgoCD app (`cluster/apps/linkerd/`)
  - [ ] Control plane (linkerd-crds + linkerd-control-plane charts)
  - [ ] Annotate all namespaces for mesh injection
  - [ ] linkerd-viz extension for dashboard + golden metrics

---

### Phase 2 — Observability stack (fix + complete)
**Goal:** Full LGTM stack running in cluster, managed by ArgoCD.
After this phase: metrics, logs, and traces are flowing.

- [ ] kube-prometheus-stack (Prometheus + Alertmanager) — Helm ArgoCD app
- [ ] Thanos — sidecar mode for long-term storage
- [ ] Grafana — provisioned dashboards via ConfigMap
- [ ] Loki + Promtail — log aggregation
- [ ] Tempo — distributed tracing backend
- [ ] OpenTelemetry Collector — receives OTLP, routes to Tempo + Prometheus

### Phase 3 — Policy as code
**Goal:** Kyverno running, real policies enforced cluster-wide.
After this phase: any manifest that violates policy is rejected at admission.

- [ ] Kyverno — Helm ArgoCD app
- [ ] Policy: require resource limits on all pods
- [ ] Policy: disallow `:latest` image tag
- [ ] Policy: require `app` and `env` labels on all workloads
- [ ] Policy: disallow running as root (runAsNonRoot)
- [ ] Policy: privileged containers must have explicit annotation (for Warden DaemonSet)

### Phase 4 — Warden (container provisioning engine)
**Goal:** Warden running as privileged DaemonSet, instrumented with OTEL, gRPC endpoint exposed.
After this phase: Warden accepts container provisioning requests, emits traces to Tempo, metrics to Prometheus.

#### Phase 4a — Warden runtime
- [ ] Proto definition: `RunContainer`, `StopContainer`, `ListContainers` RPCs
- [ ] gRPC server skeleton (v0.1 — os/exec based, just to get it deployed)
- [ ] Dockerfile (distroless base)
- [ ] DaemonSet manifest (privileged, CAP_SYS_ADMIN, hostPID)
- [ ] ServiceMonitor for Prometheus scraping
- [ ] OTEL instrumentation (traces per container op, metrics: spawn count, latency histogram)
- [ ] v0.2: real namespace isolation (CLONE_NEWPID, CLONE_NEWNET, CLONE_NEWUTS)
- [ ] v0.3: cgroup v2 resource limits (CPU + memory)
- [ ] v0.4: overlayfs image layers

#### Phase 4b — WardenRuntime operator
- [ ] CRD: `WardenRuntime` (spec: cgroupDriver, maxContainers, logLevel)
- [ ] controller-runtime based reconciler
- [ ] Reconcile loop: WardenRuntime exists → ensure DaemonSet configured correctly
- [ ] Status conditions: Ready, Degraded
- [ ] Deploy operator as Deployment in cluster

### Phase 5 — SLI/SLO layer
**Goal:** SLOs defined for Warden, error budget tracked, burn alerts firing.
After this phase: any reliability regression in Warden shows up as error budget burn.

- [ ] SLI definitions:
  - Availability: % of RunContainer RPCs that succeed (Warden)
  - Latency: p99 container spawn time < 500ms (Warden)
- [ ] PrometheusRules: recording rules for SLI metrics
- [ ] PrometheusRules: multi-window burn rate alerts (5m + 1h)
- [ ] Grafana SLO dashboard: error budget remaining, burn rate graph, SLI trend
- [ ] Alertmanager route: burn alert → (webhook or just visible in Grafana)

### Phase 6 — Chaos Engineering
**Goal:** Chaos experiments validate that SLOs hold under failure conditions.
After this phase: documented evidence that the platform self-heals.

- [ ] Chaos Mesh — Helm ArgoCD app
- [ ] Experiment 1: PodChaos — kill Warden pod, verify DaemonSet recovers, SLO holds
- [ ] Experiment 2: NetworkChaos — inject 200ms latency on Warden gRPC, verify p99 alert fires
- [ ] Experiment 3: StressChaos — CPU stress on node, verify cgroup limits hold

---

## The GitOps rule (enforced after Phase 1)

```
Who does what:
  Ansible      → OS layer only (k3s, kubeconfig). Runs from your Mac.
  kubectl      → Bootstrap only (namespaces, Gitea, ArgoCD). Runs once, ever.
  git push     → Everything else. This is the only way to change cluster state.
  make up/down → Orchestrates all of the above in order.
```

| Action | How | Never |
|--------|-----|-------|
| OS/k3s changes | `ansible-playbook` | — |
| Bootstrap (once) | `kubectl apply` | — |
| Everything else | `git push` | `kubectl apply` directly |

---

## Interview angles per phase

| Phase | What you can say |
|-------|-----------------|
| 1 | "I bootstrapped a k3s cluster with Ansible (idempotent, one command), then handed control to ArgoCD app-of-apps backed by a self-hosted Gitea instance" |
| 1.5 | "The entire CI/CD pipeline runs inside the cluster — ARC runners build and push images to Gitea's OCI registry, ArgoCD Image Updater promotes them automatically. GitHub never touches an image." |
| 2 | "Full LGTM stack: Prometheus with Thanos for long-term storage, Loki for logs, Tempo for traces, all correlated in Grafana. I chose Thanos over Mimir because it's what InfraCloud runs." |
| 3 | "Kyverno enforces four policies cluster-wide — resource limits required, no latest tags, non-root mandatory, and privileged containers need an explicit annotation. Any manifest that violates these is rejected at admission." |
| 4a | "Warden is a container provisioning engine — it accepts RunContainer RPCs over gRPC and uses Linux namespaces and cgroup v2 to isolate workloads. Same primitives Docker uses, built from scratch." |
| 4b | "I wrote a Kubernetes operator with controller-runtime that manages Warden's config via a WardenRuntime CRD. The reconciler watches for drift and corrects it — standard operator pattern." |
| 5 | "I defined two SLIs for Warden: availability (% successful RunContainer calls) and latency (p99 spawn time). PrometheusRules track error budget burn rate with multi-window alerts. The Grafana dashboard shows budget remaining in real time." |
| 6 | "I ran three chaos experiments: pod kill (DaemonSet self-heals), network latency injection (p99 alert fires as expected), and CPU stress (cgroup limits hold). The SLOs survived all three." |

---

## Resume bullet (after completion)

> Built platform-zero: portable one-command SRE platform on bare-metal k3s —
> ArgoCD app-of-apps (self-hosted Gitea backend), self-contained CI/CD via ARC runners
> + Gitea OCI registry, Kyverno admission policies, full LGTM observability stack with
> Thanos, OTEL distributed tracing, SLI/SLO dashboards with multi-window error budget
> burn alerts, Warden container provisioning engine (Go + gRPC + Linux namespaces/cgroups/
> overlayfs), WardenRuntime K8s operator (controller-runtime), and Chaos Mesh experiments.
> Zero hardcoded config — portable via .env.
