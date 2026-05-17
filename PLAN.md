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
- **Networking** — Traefik ingress + cert-manager + Let's Encrypt + Linkerd service mesh + Cilium eBPF
- **Observability** — Prometheus + Thanos + Grafana + Loki + Tempo (full LGTM stack)
- **Distributed tracing** — OpenTelemetry Collector + Tempo
- **Policy as code** — Kyverno admission controller with real policies
- **SLI/SLO** — PrometheusRules, error budget burn alerts, Grafana SLO dashboard
- **Self-contained CI/CD** — Gitea Actions + act_runner + Gitea OCI registry + ArgoCD Image Updater
- **Chaos Engineering** — Chaos Mesh experiments against cluster workloads
- **Kubernetes controller** — custom CRD + controller-runtime reconciler, deployed via ArgoCD
- **AWS IaC** — Terraform modules + Terragrunt multi-env against local Ministack
- **GCP IaC** — Terraform modules + Terragrunt multi-env against local GCP emulators
- **Ansible lab** — multi-tier app deployment: PostgreSQL replication, nginx, backups, Molecule tests
- **Database operations** — PostgreSQL HA with Patroni, PgBouncer, WAL-G backups, PITR testing, Bytebase schema migration governance

---

## Gap coverage (why this project exists)

| Skill gap | Tier | Covered by |
|-----------|------|------------|
| ArgoCD | 1 | Core GitOps backbone |
| Secret management (Vault) | 1 | Phase 1.6 — Vault + ESO |
| SLI/SLO/error budgets | 1 | Phase 4 — PrometheusRules + Grafana |
| Linkerd service mesh | 2 | Phase 1.8 — networking layer |
| cert-manager / Let's Encrypt | 2 | Phase 1.8 — networking layer |
| Kyverno | 2 | Phase 3 — admission policies |
| OpenTelemetry | 2 | Phase 2 — OTEL Collector + Tempo |
| Distributed tracing | 2 | Phase 2 — Tempo + Grafana |
| Thanos | InfraCloud | Phase 2 — long-term Prometheus storage |
| Self-hosted CI/CD runners | Luxor depth | Phase 1.5 — Gitea Actions + act_runner |
| Chaos Engineering | InfraCloud | Phase 5 — Chaos Mesh |
| Kubernetes operators / CRDs | 1 | controller/ — controller-runtime reconciler |
| GCP IaC | 2 | gcplab/ — Terraform + Terragrunt |
| Ansible at depth | 2 | ansible-lab/ — roles, Molecule, multi-tier deploy |
| Database HA (Patroni, PgBouncer) | 1 | dblab/ — PostgreSQL HA + WAL-G + PITR |
| eBPF / Cilium | 2 | k8slab Phase 6 — Cilium + Hubble |
| Networking internals | 2 | networkinglab/ — eBPF, BGP, WireGuard, packet tracing |
| Supply chain security | 2 | securitylab/ — SBOM, Cosign, Falco, OPA, CIS |
| Internal developer platform | 3 | platformlab/ — Backstage, golden paths, self-service |

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
│       ├── slo/                   ← Phase 4
│       │   ├── prometheusrules.yaml
│       │   └── grafana-dashboard.yaml
│       └── chaos/                 ← Phase 5
│           ├── chaos-mesh/        ← Chaos Mesh install
│           └── experiments/       ← chaos experiments
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
**Goal:** Gitea Actions runner running inside the cluster, ready to pick up workflow jobs.
After this phase: any `.gitea/workflows/` file in the repo triggers a build inside k3s.

- [x] act-runner — Helm ArgoCD app (`cluster/apps/act-runner/`)
  - [x] Registration token sourced from Vault via ExternalSecret
  - [x] Registers with Gitea at `http://gitea-http.gitea.svc.cluster.local:3000`
  - [x] Picks up any job with `runs-on: ubuntu-latest`
- [x] ArgoCD Image Updater — Helm ArgoCD app
  - [x] Configured to watch Gitea OCI registry
  - [x] Write-back: updates image tag in manifest on new push

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

### Phase 1.7 — IaC: Terraform (Vault + MinIO + Cloudflare)
**Goal:** Full lifecycle management of Vault configuration, MinIO buckets/ACLs, and Cloudflare tunnel/DNS via Terraform. Replaces all shell-based provisioning in bootstrap.yaml and activate.yaml.
After this phase: `terraform apply` idempotently provisions all external service config. State is tracked. Access management is auditable in code.

**Architecture:**
```
make up          → Ansible: OS, k3d, ArgoCD, Gitea, Vault init/unseal, MinIO deploy
terraform apply  → Terraform: Vault policies + auth roles + KV secrets, MinIO buckets + users, CF tunnel + DNS
ArgoCD           → syncs workloads (reads from Vault via ESO, unchanged)
```

**Providers:**
- `hashicorp/vault` — official. Manages auth methods, policies, KV engines, K8s auth roles
- `aminueza/minio` — community. Manages buckets, bucket policies, service accounts
- `cloudflare/cloudflare` — official. Manages tunnel, DNS records

**State backend:** MinIO S3 backend (`terraform { backend "s3" {} }`) — Terraform state for MinIO config stored in MinIO itself. Satisfying recursion; keeps everything self-contained.

**Structure:**
```
terraform/
├── main.tf               ← root module, provider config from .env
├── variables.tf
├── outputs.tf
├── modules/
│   ├── vault/            ← KV engine, ESO policy, K8s auth role, secret seeding
│   ├── minio/            ← thanos bucket, policies, service accounts
│   └── cloudflare/       ← tunnel, DNS records (grafana/argocd/gitea/prometheus)
└── backend.tf            ← S3 backend pointing at local MinIO
```

**What moves out of bootstrap.yaml:**
- All `vault kv put` tasks → `vault` module resources
- All `vault write auth/kubernetes/...` tasks → `vault` module resources
- Cloudflare tunnel + DNS record creation → `cloudflare` module

**What moves out of activate.yaml:**
- MinIO `thanos` bucket creation → `minio` module (Helm hook skip is no longer relevant)

**Interview angle:** "I use Terraform for the lifecycle of services the cluster depends on — Vault auth config, MinIO bucket provisioning, Cloudflare tunnel — so the Ansible bootstrap stays minimal and the entire provisioning layer is idempotent and reviewable in code."

- [ ] `terraform/modules/vault/` — KV v2 engine, ESO policy, K8s auth method + role, KV secrets (grafana, minio, act-runner)
- [ ] `terraform/modules/minio/` — `thanos` bucket, read/write policy, service account
- [ ] `terraform/modules/cloudflare/` — tunnel resource, 4 DNS CNAME records
- [ ] `terraform/main.tf` — root module wiring providers from `.env` vars
- [ ] `terraform/backend.tf` — S3 backend on local MinIO (`thanos` bucket, `terraform/` prefix)
- [ ] `terraform/variables.tf` — all inputs: vault_addr, minio_endpoint, cf_api_token, etc.
- [ ] Remove Vault seeding tasks from `bootstrap.yaml` (replaced by Terraform)
- [ ] Remove MinIO bucket task from `activate.yaml` (replaced by Terraform)
- [ ] Remove Cloudflare API tasks from `bootstrap.yaml` (replaced by Terraform)
- [ ] Add `terraform init && terraform apply -auto-approve` step to `make up` (after ArgoCD activates, before success message)
- [ ] `terraform/` added to `.gitignore` for `.terraform/` and `*.tfstate*`

---

### Phase 1.8 — Networking layer (Traefik + cert-manager + Linkerd)
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

### Phase 4 — SLI/SLO layer
**Goal:** SLOs defined for the platform, error budget tracked, burn alerts firing.
After this phase: any reliability regression in the cluster shows up as error budget burn.

- [ ] SLI definitions:
  - Availability: % of successful requests to the demo workload (emojivoto)
  - Latency: p99 response time < 500ms
- [ ] PrometheusRules: recording rules for SLI metrics
- [ ] PrometheusRules: multi-window burn rate alerts (5m + 1h)
- [ ] Grafana SLO dashboard: error budget remaining, burn rate graph, SLI trend
- [ ] Alertmanager route: burn alert visible in Grafana

### Phase 5 — Chaos Engineering
**Goal:** Chaos experiments validate that SLOs hold under failure conditions.
After this phase: documented evidence that the platform self-heals.

- [ ] Chaos Mesh — Helm ArgoCD app
- [ ] Experiment 1: PodChaos — kill demo workload pod, verify SLO holds
- [ ] Experiment 2: NetworkChaos — inject latency, verify p99 alert fires
- [ ] Experiment 3: StressChaos — CPU stress on node, verify cluster self-heals

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
| 1.5 | "The CI/CD runner lives inside the cluster — act-runner registers with Gitea, picks up workflow jobs, and can push images directly to Gitea's OCI registry. Nothing leaves the homelab network." |
| 2 | "Full LGTM stack: Prometheus with Thanos for long-term storage, Loki for logs, Tempo for traces, all correlated in Grafana. I chose Thanos over Mimir because it's what InfraCloud runs." |
| 3 | "Kyverno enforces four policies cluster-wide — resource limits required, no latest tags, non-root mandatory, and privileged containers need an explicit annotation. Any manifest that violates these is rejected at admission." |
| 4 | "I defined two SLIs for the platform: availability and p99 latency. PrometheusRules track error budget burn rate with multi-window alerts. The Grafana dashboard shows budget remaining in real time." |
| 5 | "I ran three chaos experiments: pod kill (deployment self-heals), network latency injection (p99 alert fires as expected), and CPU stress (cluster recovers). The SLOs survived all three." |

---

## Resume bullet (after completion)

> Built platform-zero: portable one-command SRE platform on bare-metal k3s —
> ArgoCD app-of-apps (self-hosted Gitea backend), Gitea Actions CI/CD with OCI registry,
> Kyverno admission policies, full LGTM observability stack with Thanos, OTEL distributed
> tracing, SLI/SLO dashboards with multi-window error budget burn alerts, and Chaos Mesh
> experiments. Zero hardcoded config — portable via .env.

---

## k8slab — Phase 6: eBPF networking (Cilium)

**Goal:** Replace kube-proxy with Cilium. Enable Hubble for network-level observability.
Write real L3/L4/L7 network policies. Show what eBPF-based networking looks like vs
traditional iptables.

After this phase: every pod-to-pod flow is visible in Hubble UI. Network policies enforced
at the kernel level, not userspace.

- [ ] Reinstall k3d cluster with `--k3s-arg "--flannel-backend=none"` to disable default CNI
- [ ] Cilium — Helm ArgoCD app (`cluster/infra/cilium/`)
  - [ ] kube-proxy replacement mode enabled
  - [ ] Hubble enabled with UI + Relay
  - [ ] NodePort services still reachable (confirm ArgoCD, Gitea, Grafana still work)
- [ ] Network policies:
  - [ ] Default-deny all ingress in `monitoring` namespace
  - [ ] Allow Prometheus to scrape all namespaces (explicit allow)
  - [ ] Block cross-namespace traffic between `gitea` and `vault`
- [ ] Hubble UI — exposed via Cloudflare Tunnel
- [ ] Grafana dashboard — Cilium golden signals (drop rate, policy verdict, DNS latency)

**Interview angle:** "I replaced kube-proxy with Cilium in eBPF mode — all packet processing
happens in kernel space, no iptables rules. Hubble gives per-flow visibility into every
connection in the cluster. I enforced L7 HTTP policies which iptables can't do at all."

---

## gcplab — GCP infrastructure via Terraform

**Goal:** Mirror awslab for GCP. Same Terragrunt multi-env pattern. Run against local GCP
emulators instead of real GCP — no cloud bill.

After this phase: anyone can practice GCP IaC patterns without a GCP account.

### Phase 1 — Local GCP emulators
- [ ] `docker-compose.yml` — fake-gcs-server (GCS), Cloud SQL Proxy (Cloud SQL), Pub/Sub emulator
- [ ] `make up` — starts all emulators, seeds test data
- [ ] `env.sh` — sets `STORAGE_EMULATOR_HOST`, `PUBSUB_EMULATOR_HOST`, etc.
- [ ] Confirm `gcloud` and Terraform GCP provider work against emulators

### Phase 2 — Terraform modules
- [ ] `modules/vpc/` — VPC, subnets (public/private), Cloud Router, Cloud NAT
- [ ] `modules/iam/` — service accounts, IAM bindings, workload identity
- [ ] `modules/gcs/` — buckets, lifecycle policies, versioning, IAM
- [ ] `modules/cloud-sql/` — PostgreSQL instance, private IP, authorized networks
- [ ] `modules/gke/` — GKE cluster (Autopilot-compatible config), node pools
- [ ] `modules/cloud-run/` — service deployment, VPC connector, IAM invoker

### Phase 3 — Terragrunt multi-env
- [ ] `live/dev/` — dev environment wiring all modules
- [ ] `live/staging/` — staging environment, isolated from dev
- [ ] Shared `root.hcl` with GCS backend for state
- [ ] `make apply ENV=dev` and `make apply ENV=staging`

**Interview angle:** "Same Terragrunt multi-env pattern as AWS, different provider. I can
walk through GCS vs S3, Cloud SQL vs RDS, service accounts vs IAM roles — the concepts
transfer, the config details differ."

---

## ansible-lab — Ansible at depth

**Goal:** Go beyond basic roles. Build a complete multi-tier application deployment
using only Ansible — idempotent, testable, production-like.

After this phase: can deploy, update, and recover a multi-tier app across multiple
nodes with a single command. Every role has Molecule tests.

### What gets built
Three nodes (Docker containers via Molecule or Vagrant VMs):
- `db` node — PostgreSQL primary + replica (streaming replication)
- `app` node — Python/Go app served by gunicorn
- `lb` node — nginx reverse proxy with health checks

### Phase 1 — Role structure + Molecule setup
- [ ] `roles/common/` — OS hardening, SSH config, fail2ban, chronyc
- [ ] `roles/postgres/` — install, configure, init DB, manage users, replication
- [ ] `roles/app/` — deploy app binary, systemd unit, environment config
- [ ] `roles/nginx/` — upstream config, health check endpoint, TLS termination
- [ ] Molecule scenario per role — Docker driver, verify playbook
- [ ] CI: `.gitea/workflows/molecule.yaml` — runs Molecule on every push

### Phase 2 — Inventory + secrets
- [ ] Dynamic inventory via custom plugin (reads from `.env` or JSON file)
- [ ] Vault integration — secrets fetched from Vault, not hardcoded in vars
- [ ] `group_vars/` structured by environment (dev/staging)

### Phase 3 — Operational playbooks
- [ ] `deploy.yaml` — rolling deploy without downtime (serial: 1)
- [ ] `backup.yaml` — pg_dump to MinIO on schedule
- [ ] `failover.yaml` — promote replica to primary, reconfigure app to new primary
- [ ] `restore.yaml` — restore from MinIO backup, verify data integrity
- [ ] Each playbook idempotent — safe to re-run at any time

**Interview angle:** "I wrote Ansible roles with Molecule tests — each role is tested in
isolation against a Docker container before being applied. The deploy playbook is rolling
with serial: 1, so the app stays up during updates. I also wrote a failover playbook that
promotes the PostgreSQL replica and reconfigures the app tier — tested and documented."

---

## controller/ — Kubernetes controller

**Goal:** Write a real Kubernetes controller from scratch using controller-runtime.
Educational content — clean code, detailed README that teaches the pattern.

After this phase: anyone can read this code and understand how every K8s controller works.

### What it does
CRD: `NamespaceConfig`

```yaml
apiVersion: platform.zero/v1alpha1
kind: NamespaceConfig
metadata:
  name: monitoring-config
spec:
  namespace: monitoring
  labels:
    team: platform
    env: prod
  resourceQuota:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
  limitRange:
    defaultCpu: 500m
    defaultMemory: 512Mi
```

Controller watches `NamespaceConfig` objects. For each one:
- Ensures the target namespace has the required labels
- Creates/updates a `ResourceQuota` in that namespace
- Creates/updates a `LimitRange` in that namespace
- Reconciles on drift — if someone manually deletes the quota, it comes back

### Build phases
- [ ] `api/v1alpha1/namespacecconfig_types.go` — CRD type definition
- [ ] `controllers/namespaceconfig_controller.go` — reconcile loop
  - [ ] List target namespace, patch labels
  - [ ] Apply ResourceQuota (create if missing, update if drifted)
  - [ ] Apply LimitRange (same)
  - [ ] Update status condition: `Ready=True` or `Ready=False` with reason
- [ ] `config/crd/` — generated CRD YAML (`make generate && make manifests`)
- [ ] `config/rbac/` — ClusterRole, ClusterRoleBinding
- [ ] `Dockerfile` — distroless base, multi-stage build
- [ ] `cluster/apps/controller/` — ArgoCD app, deployed into k8slab
- [ ] `README.md` — explains every part of the reconcile loop with annotations

**Interview angle:** "I wrote a controller with controller-runtime that watches a custom
NamespaceConfig CRD. The reconcile loop ensures ResourceQuotas and LimitRanges are always
present — if someone deletes a quota manually, the controller recreates it within seconds.
Status conditions surface the reconciliation state. Same pattern as every controller in
the K8s ecosystem."

---

## dblab/ — Database operations at depth

**Goal:** Full PostgreSQL lifecycle — HA, pooling, backups, recovery, performance
debugging, schema migrations, and cross-cloud migration — all hands-on, runnable locally
via Docker Compose, with realistic seed data for every scenario.

After this phase: can demonstrate and explain every database problem you will face in a
startup or enterprise SRE role. Every scenario has a runbook.

### Seed data strategy

Each phase uses one of four seed datasets depending on what it needs to test:

| Dataset | How to load | Rows | Best for |
|---------|------------|------|---------|
| `pgbench -i -s 100` | built-in CLI | ~10M | Bloat drills, performance, connection exhaustion |
| `dvdrental` | pg_restore from dump | ~80k | Query optimization, EXPLAIN ANALYZE, joins |
| `seed/business.sql` | custom script | configurable | Online schema changes, CDC lab, migration drills |
| TPC-H (`dbgen -s 1`) | generate + COPY | ~6M | Analytics queries, partitioning, index design |

`seed/business.sql` generates a realistic `users`, `orders`, `order_items`, `products`
schema using `generate_series()` — no external dependency, scales to any size.

```sql
-- example: 5M orders across 100k users
INSERT INTO orders SELECT
  generate_series(1, 5000000) AS id,
  (random() * 99999 + 1)::int AS user_id,
  now() - (random() * interval '2 years') AS created_at,
  CASE WHEN random() < 0.85 THEN 'completed' ELSE 'pending' END AS status;
```

### Architecture

```
                    ┌─────────────────────────┐
                    │       PgBouncer         │  ← connection pool (port 5432)
                    └────────────┬────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                  │
       ┌──────▼──────┐   ┌───────▼──────┐   ┌──────▼──────┐
       │  primary    │   │  replica-1   │   │  replica-2  │
       │  Patroni    │◄──│  streaming   │◄──│  streaming  │
       └──────┬──────┘   └─────────────┘   └─────────────┘
              │
       ┌──────▼──────┐
       │    WAL-G    │  ← continuous WAL archive to MinIO
       │  MinIO S3   │
       └─────────────┘
```

### Phase 1 — Patroni HA cluster
- [ ] `docker-compose.yml` — 3 PostgreSQL nodes + etcd (Patroni DCS) + PgBouncer
- [ ] Patroni config per node (`patroni.yml`) — primary election, replication settings
- [ ] etcd cluster for distributed consensus (3-node)
- [ ] `make up` — full cluster in under 2 minutes
- [ ] Verify: `patronictl list` shows primary + replicas, replication lag = 0

### Phase 2 — PgBouncer connection pooling
- [ ] PgBouncer in transaction pooling mode (most efficient for app servers)
- [ ] `pgbouncer.ini` — pool size, max client connections, auth
- [ ] `userlist.txt` — hashed passwords, no plaintext
- [ ] Demonstrate: 1000 app connections, 10 server connections via pool

### Phase 3 — WAL-G backups to MinIO
- [ ] WAL-G configured on primary — continuous WAL archiving to MinIO bucket
- [ ] `backup.sh` — base backup on schedule (cron or Ansible)
- [ ] Verify: `walg wal-verify integrity` confirms no WAL gaps

### Phase 4 — Point-in-time recovery (the real test)
- [ ] Insert data at T1. Corrupt database at T2. Recover to T1.
  - [ ] `make chaos-db` — simulates data corruption (delete a table)
  - [ ] `make restore TIME="2026-05-17 14:30:00"` — restores from WAL archive to that moment
  - [ ] Verify recovered data matches pre-corruption state
- [ ] Document the recovery steps as a runbook (`docs/pitr-runbook.md`)

### Phase 5 — Monitoring
- [ ] `postgres_exporter` — scrape replication lag, connections, transaction rate
- [ ] Grafana dashboard — primary/replica lag, PgBouncer pool utilization, WAL archive rate
- [ ] Alerts: replica lag > 30s, archive failure, connection saturation > 80%, long-running queries > 30s
- [ ] `pg_stat_statements` enabled — top 10 slowest queries visible in Grafana

---

### Phase 6 — Bloat simulation and pg_repack

**Why:** After mass updates or deletes, PostgreSQL leaves dead tuples in place (MVCC).
The table grows but disk is never reclaimed. Queries slow down scanning dead rows.
If autovacuum falls behind, you risk transaction ID wraparound — PostgreSQL freezes the
entire database as protection. Most engineers know this exists. Almost nobody has seen it.

- [ ] Seed table with 5M rows
- [ ] Run mass UPDATE (update every row) — measure table size before and after
- [ ] Observe: table is now 2x the size despite same row count (`pg_relation_size`)
- [ ] Measure bloat: `pgstattuple` extension, `pg_bloat_info` query
- [ ] Run `VACUUM VERBOSE` — observe dead tuples reclaimed, size unchanged (VACUUM doesn't shrink)
- [ ] Run `pg_repack` on live table — table shrinks without exclusive lock, zero downtime
- [ ] Run `VACUUM FULL` on offline table — compare: same result, but locks table
- [ ] Autovacuum tuning: `autovacuum_vacuum_scale_factor`, `autovacuum_vacuum_threshold`
- [ ] Simulate wraparound risk: monitor `age(datfrozenxid)` via `pg_database`
- [ ] Document: `docs/bloat-runbook.md` — how to detect, measure, fix bloat

**Interview angle:** "I simulated table bloat by mass-updating 5M rows and watched the
table double in size. VACUUM reclaims dead tuples but doesn't shrink the table — for that
you need pg_repack which rewrites the table live without blocking reads or writes. I also
know how to tune autovacuum so it keeps up with write-heavy tables before bloat builds up."

---

### Phase 7 — Query performance debugging (EXPLAIN ANALYZE lab)

**Why:** "Our API is slow" is the most common production problem. The path from symptom
to fix always goes through pg_stat_activity, pg_stat_statements, and EXPLAIN ANALYZE.
This is asked in almost every SRE and backend interview.

- [ ] Enable `pg_stat_statements` extension in `postgresql.conf`
- [ ] Seed realistic schema: `users`, `orders`, `order_items`, `products` (millions of rows)
- [ ] Scenario 1 — Missing index
  - [ ] Run query filtering on non-indexed column, observe seq scan in EXPLAIN
  - [ ] Add index, re-run, observe index scan + time drop
  - [ ] Learn: why seq scan sometimes wins (small tables, low selectivity)
- [ ] Scenario 2 — Wrong index type
  - [ ] JSONB column with GIN vs B-tree — query with `@>` operator, show difference
  - [ ] Partial index: `CREATE INDEX ... WHERE status = 'pending'` — smaller, faster for filtered queries
  - [ ] Composite index column order: `(user_id, created_at)` vs `(created_at, user_id)` — when each wins
- [ ] Scenario 3 — N+1 query pattern
  - [ ] Show 1000 single-row selects vs one `IN (...)` query — time comparison in `pg_stat_statements`
- [ ] Scenario 4 — Stale statistics
  - [ ] Load 5M rows, run query (bad plan). Run `ANALYZE`. Re-run (good plan). Explain why.
- [ ] Scenario 5 — Lock contention
  - [ ] Long-running transaction holding lock. Second transaction blocked. Observe in `pg_stat_activity`.
  - [ ] `pg_blocking_pids()` — identify the blocker
  - [ ] `pg_cancel_backend()` vs `pg_terminate_backend()` — when to use each
- [ ] Build a query: `docs/slow-query-runbook.md` — the exact steps to debug any slow query

**Interview angle:** "I ran an EXPLAIN ANALYZE lab with realistic data — missing indexes,
wrong index types, stale statistics, lock contention. I know how to read the query plan:
rows estimate vs actual, cost units, seq scan vs index scan vs bitmap heap scan. The first
thing I check for a slow query is pg_stat_statements sorted by total_time, then EXPLAIN
ANALYZE on the worst offenders."

---

### Phase 8 — Online schema changes (zero-downtime migrations)

**Why:** Adding a column to a 50M row table with a naïve ALTER TABLE takes an exclusive
lock and blocks all reads and writes. In production that means downtime. The correct path
is longer but non-blocking. This question comes up in every startup interview.

- [ ] Seed `users` table with 10M rows
- [ ] Demonstrate the WRONG way: `ALTER TABLE users ADD COLUMN verified BOOLEAN NOT NULL DEFAULT false`
  - [ ] Observe: ACCESS EXCLUSIVE lock held for ~30 seconds on 10M rows — production down
- [ ] The RIGHT way — expand-contract pattern:
  - [ ] Step 1: `ADD COLUMN verified BOOLEAN` (nullable, instant, no lock)
  - [ ] Step 2: backfill in batches of 10k rows with `pg_sleep(0.01)` rate limiting
  - [ ] Step 3: `ADD CONSTRAINT verified_not_null CHECK (verified IS NOT NULL) NOT VALID` (no table scan)
  - [ ] Step 4: `VALIDATE CONSTRAINT` (ShareUpdateExclusiveLock — reads still work)
  - [ ] Step 5: `ALTER COLUMN SET NOT NULL` using the validated constraint (instant)
- [ ] `CREATE INDEX CONCURRENTLY` vs `CREATE INDEX`
  - [ ] Show: regular index creation blocks writes, CONCURRENTLY does not
  - [ ] Caveat: CONCURRENTLY takes longer, can fail if concurrent writes conflict
- [ ] `pg_repack` for type changes
  - [ ] Change column type on large table — normally rewrites entire table with exclusive lock
  - [ ] pg_repack approach: build new table in background, swap atomically
- [ ] Major version upgrade without downtime via logical replication
  - [ ] PG 15 primary → PG 16 replica via logical replication
  - [ ] Sync, then promote PG 16, point app at new primary
  - [ ] Total downtime: seconds (DNS flip), not hours (dump + restore)
- [ ] Document: `docs/schema-migration-patterns.md`

**Interview angle:** "Adding a NOT NULL column to a large table is a classic downtime trap.
The safe pattern is: add nullable first, backfill in rate-limited batches, add the NOT NULL
constraint with NOT VALID so it doesn't scan existing rows, then validate separately with a
weaker lock. I've run this on a 10M row table with zero production impact."

---

### Phase 9 — Logical replication and CDC

**Why:** Physical (streaming) replication copies WAL byte-for-byte — same version, same
everything. Logical replication decodes WAL into row changes — you can replicate specific
tables, replicate across major PostgreSQL versions, or stream every change to Kafka.
CDC (Change Data Capture) is how modern data pipelines, audit logs, and event-driven
systems are built.

- [ ] Logical replication between two PostgreSQL instances (same compose)
  - [ ] Create `PUBLICATION` on source: `CREATE PUBLICATION app_pub FOR TABLE users, orders`
  - [ ] Create `SUBSCRIPTION` on target: `CREATE SUBSCRIPTION app_sub ...`
  - [ ] Verify: inserts/updates/deletes on source appear on target within milliseconds
  - [ ] Test selective replication: add `products` to publication, verify it syncs
- [ ] Debezium + Redpanda (Kafka-compatible) CDC pipeline
  - [ ] `docker-compose.yml` adds: Redpanda, Redpanda Console, Debezium connector
  - [ ] Configure Debezium PostgreSQL connector — enable `wal_level = logical`
  - [ ] Every insert/update/delete on `orders` table becomes a Kafka message
  - [ ] Consume messages with `rpk topic consume orders` — see the change events
  - [ ] Show envelope format: `before` state + `after` state + operation type
- [ ] Use cases to document:
  - [ ] Audit log — every change recorded without application code changes
  - [ ] Cache invalidation — Redis cache busted on DB change without polling
  - [ ] Event sourcing — order state changes as event stream
  - [ ] Zero-downtime major version upgrade (PG 15 → PG 16 via logical rep)

**Interview angle:** "I set up a Debezium CDC pipeline — every change to the orders table
appears as a structured event in Redpanda within milliseconds. The envelope has the before
and after state of the row plus the operation type. I use this pattern for audit logs and
cache invalidation without polling. I also used logical replication for a major version
upgrade: replicate from PG 15 to PG 16, let it catch up, flip the connection string —
total downtime was under 10 seconds."

---

### Phase 10 — Fire drills (simulate real incidents)

**Why:** Knowing what to do and having done it are different. These drills simulate real
production incidents you will face as a DBA or SRE. Each has a `make` target, a symptom
description, a diagnosis path, and a fix.

- [ ] Drill 1 — Connection exhaustion
  - [ ] `make drill-connections` — spawn 500 connections to bypass PgBouncer directly
  - [ ] Symptom: `FATAL: sorry, too many clients already`
  - [ ] Diagnose: `SELECT count(*), state FROM pg_stat_activity GROUP BY state`
  - [ ] Fix: kill idle connections, tune `max_connections`, route traffic through PgBouncer
  - [ ] Prevention: PgBouncer pool sizing formula, connection limits per role

- [ ] Drill 2 — Replication lag spike
  - [ ] `make drill-lag` — run heavy write workload on primary
  - [ ] Symptom: replica lag climbs, read queries return stale data
  - [ ] Diagnose: `pg_stat_replication`, `pg_wal_lsn_diff(sent_lsn, replay_lsn)`
  - [ ] Fix: identify write hotspot, reduce checkpoint pressure, tune `wal_compression`
  - [ ] Alert threshold: lag > 30s triggers page

- [ ] Drill 3 — Long-running transaction blocking vacuum
  - [ ] `make drill-lock` — start transaction, leave it open for 5 minutes
  - [ ] Symptom: autovacuum skips table, bloat builds, `xmin` horizon stuck
  - [ ] Diagnose: `pg_stat_activity WHERE state = 'idle in transaction'`
  - [ ] Fix: `pg_terminate_backend()` on the idle transaction, run VACUUM manually
  - [ ] Prevention: `idle_in_transaction_session_timeout` setting

- [ ] Drill 4 — Disk filling with WAL
  - [ ] `make drill-wal` — disable WAL archiving, generate heavy writes
  - [ ] Symptom: `/var/lib/postgresql/data/pg_wal` grows until disk full, DB crashes
  - [ ] Diagnose: `pg_ls_waldir()`, check archive_status directory for failed archives
  - [ ] Fix: fix archiving, run `pg_archivecleanup`, tune `wal_keep_size`

- [ ] Drill 5 — Autovacuum not keeping up (wraparound risk)
  - [ ] `make drill-wraparound` — simulate high-write table that outpaces autovacuum
  - [ ] Symptom: `age(relfrozenxid)` approaches 2 billion — DB will freeze in self-defense
  - [ ] Diagnose: `SELECT relname, age(relfrozenxid) FROM pg_class ORDER BY 2 DESC`
  - [ ] Fix: manual `VACUUM FREEZE` on the table, tune autovacuum aggressiveness
  - [ ] This is a production emergency — PostgreSQL will stop accepting writes to prevent corruption

- [ ] Each drill has a `docs/drill-N-runbook.md` with: symptom, diagnosis SQL, fix, prevention

**Interview angle:** "I've run fire drills against the lab: connection exhaustion, replication
lag spike, long-running transactions blocking vacuum, WAL disk fill, and wraparound risk.
Each one has a runbook. The wraparound drill is the most important — if age(relfrozenxid)
gets close to 2 billion, PostgreSQL stops accepting writes to prevent XID wraparound
corruption. Most engineers don't know this exists until it happens in production."

---

### Phase 11 — Schema migration tooling (Bytebase)

**Why:** "How do you handle schema migrations in production?" is one of the most common
interview questions for any SRE or platform role. Most engineers say "we use Flyway" and
stop there. The real answer covers: how do you catch dangerous migrations before they run,
how does a DBA review a change before it hits production, how do you track what ran where,
and what does the approval workflow look like.

**Why Bytebase over Atlas/Flyway/Liquibase:**
Atlas and Flyway are developer CLI tools — you run them from your laptop or CI pipeline.
Bytebase is a database change management platform with a web UI, approval workflows,
audit trail, and GitOps integration. It is what companies with a DBA or platform team
actually run. The approval workflow (engineer proposes migration, DBA reviews, platform
approves, Bytebase applies) is how enterprise database changes work. Self-hosted via
Docker Compose — no cloud account required.

- [ ] Add Bytebase to `docker-compose.yml`
  - [ ] Bytebase server (port 8080) + its own metadata PostgreSQL instance
  - [ ] Connect both `dev` and `staging` database instances to Bytebase as environments
- [ ] Initial setup:
  - [ ] Create project in Bytebase — one project per application
  - [ ] Add environments: dev, staging (maps to two DB instances in compose)
  - [ ] Add database instances: connect to Patroni primary via PgBouncer
- [ ] SQL review policies (lint before apply):
  - [ ] Block: NOT NULL column without DEFAULT on existing table
  - [ ] Block: DROP TABLE or DROP COLUMN without explicit override
  - [ ] Warn: missing index on foreign key column
  - [ ] Warn: full table scan on table > 1M rows
  - [ ] Warn: lock-heavy DDL (ALTER COLUMN TYPE on large table)
- [ ] Full migration lifecycle demo:
  - [ ] Engineer creates issue in Bytebase: "add verified column to users"
  - [ ] Writes SQL: `ALTER TABLE users ADD COLUMN verified BOOLEAN DEFAULT false`
  - [ ] SQL review runs automatically — policy check passes, no block
  - [ ] DBA (second Bytebase account) reviews and approves the issue
  - [ ] Bytebase applies to dev, engineer verifies, promotes to staging
  - [ ] Audit trail: who wrote it, who approved, when it ran, what SQL
- [ ] GitOps mode (migration files in Gitea):
  - [ ] Connect Bytebase to Gitea repo — monitors `dblab/migrations/` directory
  - [ ] Engineer commits `0001_add_verified.sql` to Gitea
  - [ ] Bytebase detects new file, creates issue automatically
  - [ ] Approval workflow runs, migration applied on approval
  - [ ] Same Git workflow as cluster changes — database changes reviewed like code
- [ ] Dangerous migration demo (what gets blocked):
  - [ ] Write: `ALTER TABLE orders ADD COLUMN status VARCHAR NOT NULL` (no default, 5M rows)
  - [ ] SQL review blocks it: "NOT NULL column without default — will lock table"
  - [ ] Show the correct version: nullable first, backfill, add constraint
- [ ] Rollback strategy:
  - [ ] Bytebase supports rollback SQL per migration — write it alongside the migration
  - [ ] Forward-only for data migrations (rollback SQL is ambiguous when rows have been modified)
  - [ ] Structural rollbacks (add index, add column) are safe to roll back
  - [ ] Document: rollback decision tree in `docs/migration-rollback.md`

**Interview angle:** "We use Bytebase for database change management. Every schema change
goes through an approval workflow — engineer proposes the migration, SQL review policies
run automatically and block anything dangerous, then a DBA or platform lead approves.
Bytebase applies it to dev first, engineer verifies, then promotes to staging and prod.
Every change has an audit trail: who wrote it, who approved, when it ran. In GitOps mode,
migration files committed to Git trigger the workflow automatically — same review process
as any infrastructure change."

---

### Phase 12 — Cross-cloud database migration

**Why:** "We're moving from AWS to GCP, how do we migrate the database?" is a standard
system design question at any company that has changed cloud providers or is considering
it. There is a startup answer and an enterprise answer. Both require hands-on understanding.

Two instances simulate "Cloud A" and "Cloud B" in docker-compose. All migration patterns
work identically against real managed DBs (RDS, Cloud SQL).

#### Scenario A — Startup migration (maintenance window acceptable)

**When to use:** DB under 100GB, team can schedule 1-2 hours of downtime.

- [ ] `make migrate-dump` — `pg_dump` with `--no-owner --no-acl --format=custom` on source
- [ ] `make migrate-restore` — `pg_restore` on target, verify row counts
- [ ] Common traps to document and demonstrate:
  - [ ] Extensions not available on target managed DB (PostGIS, pg_cron, timescaledb)
  - [ ] Superuser restrictions: RDS blocks `pg_basebackup`, Cloud SQL blocks some extensions
  - [ ] Sequences reset to 1 after restore — `pg_dump` captures sequence state but restore order matters
  - [ ] Dump from PG 16 cannot restore to PG 15 — version pinning matters
  - [ ] Encoding mismatch (UTF8 vs SQL_ASCII) — set on target before restore
- [ ] Post-restore checklist: sequences, extensions, roles, connection strings, DNS flip
- [ ] Measure: total downtime from `pg_dump` start to application back up

#### Scenario B — Zero-downtime migration via logical replication

**When to use:** DB too large for dump/restore window, or SLA forbids downtime.

- [ ] Phase 1 — Schema migration first (DDL only)
  - [ ] `pg_dump --schema-only` on source, `pg_restore` on target
  - [ ] Verify: all tables, indexes, constraints exist on target, zero data
- [ ] Phase 2 — Set up logical replication
  - [ ] Source: `ALTER SYSTEM SET wal_level = logical; SELECT pg_reload_conf()`
  - [ ] Source: `CREATE PUBLICATION migration_pub FOR ALL TABLES`
  - [ ] Target: `CREATE SUBSCRIPTION migration_sub CONNECTION '...' PUBLICATION migration_pub`
  - [ ] Monitor sync: `SELECT * FROM pg_stat_subscription` — wait for `srsubstate = 'r'` (ready)
- [ ] Phase 3 — Cutover
  - [ ] Verify lag: `pg_wal_lsn_diff` on source vs `received_lsn` on target = 0
  - [ ] Set source to read-only: `ALTER DATABASE app SET default_transaction_read_only = on`
  - [ ] Confirm target caught up (lag = 0)
  - [ ] Update application connection string to target
  - [ ] Drop subscription on target: `DROP SUBSCRIPTION migration_sub`
  - [ ] Total app impact: 10-30 seconds of read-only, then full service on new DB
- [ ] Rollback plan:
  - [ ] Keep source running for 48 hours post-cutover
  - [ ] Application connection string rollback ready in environment config
  - [ ] If target fails: flip connection string back, source was never written to during cutover

#### Scenario C — Enterprise migration (compliance, large data, zero tolerance)

**When to use:** Multi-TB database, data must not leave region, compliance audit required,
rollback must be instant.

- [ ] Debezium CDC as the migration agent (source → Kafka → target)
  - [ ] Source changes stream to Kafka continuously during migration
  - [ ] Target consumes from Kafka — catches up independently, no direct DB connection required
  - [ ] Works across different database engines (Postgres → MySQL, Oracle → Postgres)
  - [ ] Required when direct network connectivity between clouds is not allowed
- [ ] Schema migration with versioned compatibility:
  - [ ] Deploy application code that works with BOTH old schema (source) and new schema (target)
  - [ ] Expand-contract pattern at the application level, not just DB level
- [ ] Validation before cutover — never skip this:
  - [ ] Row count per table: `SELECT schemaname, relname, n_live_tup FROM pg_stat_user_tables`
  - [ ] Checksum sample: `SELECT md5(CAST(t.* AS text)) FROM orders t ORDER BY random() LIMIT 10000`
  - [ ] Business logic tests: run full application test suite against target DB
  - [ ] Compare aggregates: SUM(order_total), COUNT(users), MAX(created_at) must match
- [ ] Dual-write period (optional, for highest-risk migrations):
  - [ ] Application writes to both source and target for N days
  - [ ] Compare data continuously — detect any divergence before cutover
  - [ ] Expensive but gives instant rollback: just stop writing to target
- [ ] Post-cutover:
  - [ ] Keep source in read-only mode for 7 days
  - [ ] Monitor error rates on target for 24 hours before decommissioning source
  - [ ] Document: compliance audit trail (who approved cutover, validation results, rollback plan)

#### Common traps in all migration scenarios

- [ ] Managed DB restrictions to document:
  - [ ] AWS RDS: no `pg_basebackup`, no `superuser`, limited extensions, `rds_superuser` role instead
  - [ ] GCP Cloud SQL: no direct filesystem access, Cloud SQL Proxy required, some extensions blocked
  - [ ] Both: `pg_hba.conf` managed by provider, cannot be edited directly
- [ ] Sequences: after any bulk data load, reset all sequences:
  - `SELECT setval(pg_get_serial_sequence(t, 'id'), max(id)) FROM <table> t`
- [ ] Tablespaces: do not exist on managed DBs — dump with `--no-tablespaces`
- [ ] Large objects (BLOBs): `pg_dump` with `--blobs` flag — often forgotten
- [ ] Foreign data wrappers: must be recreated manually, not included in schema dump

**Interview angle (startup):** "For a startup migration with a maintenance window we use
pg_dump + pg_restore. The common traps are extension availability on the target managed
service, sequences resetting to 1, and version compatibility. We do a dry run against a
restored copy first, measure the restore time, then schedule the window at least 2x longer."

**Interview angle (zero-downtime):** "For zero downtime we set up logical replication from
source to target, let it sync fully, then do a brief read-only window — source goes
read-only, we confirm the replica caught up with zero WAL lag, then flip the connection
string. Total app impact is under 30 seconds. Source stays up for 48 hours as instant
rollback."

**Interview angle (enterprise):** "For large-scale enterprise migrations we route changes
through a CDC pipeline — Debezium streams every row change to Kafka, target consumes
independently. This works even when direct network connectivity between clouds is
restricted. Before cutover we validate with row counts, checksum samples, and a full
application test suite. We keep the source in read-only mode for a week post-cutover.
The audit trail covers who approved, validation results, and the rollback procedure."

---

## networkinglab/ — Networking internals at depth

**Goal:** Understand the networking that awslab and k8slab run on top of — not by reading
docs, but by instrumenting it live. Trace packets through the VPC, dissect eBPF programs
running in k3s, build WireGuard from scratch to understand what Netbird actually does, and
set up BGP peering to understand how cloud routing works.

**Dependency:** awslab and k8slab must be running. networkinglab instruments them — it does
not stand alone.

**Why this matters:** Networking is the skill gap most platform engineers paper over.
Everyone knows "subnets" and "security groups." Almost nobody can explain what happens
at the kernel level when a packet crosses a pod boundary in k8s, or why iptables gets
replaced by eBPF, or how BGP converges. These questions come up in senior and staff
interviews.

### Phase 1 — Packet tracing in awslab

- [ ] `make trace-vpc` — capture traffic at the VPC boundary using Ministack's network stack
- [ ] Trace a request: client → ALB → ECS task → RDS, packet by packet
  - [ ] Show how security group rules map to actual iptables rules on the host
  - [ ] Show how NAT works at the subnet boundary (public → private subnet hop)
  - [ ] Show what the VPC route table translates to in Linux routing terms
- [ ] Document: `docs/vpc-packet-walk.md` — annotated trace of every hop
- [ ] tcpdump lab: capture ALB health checks hitting the ECS task, decode HTTP headers

**Interview angle:** "When I look at an AWS security group, I think of it as a stateful
iptables rule set managed by the hypervisor. The SG allows TCP 80 from the ALB's SG — at
the host level, that's a FORWARD chain rule matching the source security group tag. The
NAT between subnets is MASQUERADE on the NAT instance or gateway. Understanding this helped
me debug a connectivity issue that looked like a routing problem but was actually an
asymmetric SG rule."

### Phase 2 — eBPF tracing in k8slab

- [ ] Install `bpftrace` on the k3s node
- [ ] Trace pod-to-pod traffic across namespaces — show every kernel call
  - [ ] `bpftrace -e 'kprobe:tcp_sendmsg { ... }'` — see every send from k8s pods
  - [ ] Trace DNS resolution: CoreDNS → pod, show the UDP packets and responses
  - [ ] Trace a Prometheus scrape: what happens from `scrape_interval` to data in TSDB
- [ ] Show what Linkerd's sidecar proxy does to a packet:
  - [ ] Without Linkerd: HTTP packet goes directly app → app
  - [ ] With Linkerd: packet intercepted by iptables REDIRECT rule → envoy → mTLS → envoy → app
  - [ ] Capture the mTLS handshake with Wireshark — show the certificate exchange
- [ ] Cilium (Phase 6 of k8slab): compare iptables rules before and after
  - [ ] Before: `iptables -L -n -v` — hundreds of rules, kube-proxy managed
  - [ ] After Cilium: iptables mostly empty, rules replaced by eBPF maps
  - [ ] `cilium monitor` — real-time flow visibility in the kernel
  - [ ] Show a network policy drop in Cilium vs iptables — eBPF drops before packet is processed

**Interview angle:** "I traced a Linkerd mTLS connection at the kernel level. The sidecar
intercepts the outbound packet via an iptables REDIRECT rule before it leaves the pod
network namespace. It performs the TLS handshake, wraps the payload, and forwards over the
mesh. The application code sees plain HTTP — the mTLS is completely transparent. Cilium
replaces this with eBPF programs attached to the veth interface — the policy decision
happens in the kernel before the packet even reaches the network stack."

### Phase 3 — WireGuard from scratch

**Why:** Netbird uses WireGuard under the hood. Building WireGuard manually teaches what
Netbird automates — key exchange, peer config, routing, NAT traversal.

- [ ] Two Docker containers, no overlay network — raw Linux network namespaces
- [ ] `wg genkey` and `wg pubkey` — generate keypairs for both peers
- [ ] `ip link add wg0 type wireguard` — create WireGuard interface manually
- [ ] Configure peer: endpoint, allowed-ips, keepalive
- [ ] `wg setconf` — apply config, `wg show` — verify handshake
- [ ] Verify: ping across WireGuard tunnel, trace the encrypted packet with tcpdump
  - [ ] tcpdump on outer interface: UDP/51820, encrypted, meaningless
  - [ ] tcpdump on wg0: plaintext ICMP — the tunnel works
- [ ] Add routing: traffic to `10.0.0.0/8` over the tunnel
- [ ] Simulate NAT traversal — put one peer behind a simulated NAT, verify connectivity
- [ ] Then show Netbird: same WireGuard under the hood, but management plane automated
  - [ ] `netbird status` — shows all peers, endpoints, allowed IPs
  - [ ] Match each Netbird concept to the manual WireGuard config it generates

**Interview angle:** "WireGuard is a kernel module — each peer has a public/private keypair,
and you configure allowed-ips per peer which acts as both routing and firewall. When a
packet arrives on the WireGuard interface, the kernel checks the source IP against the
allowed-ips of each peer and drops it if it doesn't match. Netbird automates the key
exchange and peer discovery via its management server, but the underlying tunnel is vanilla
WireGuard. I built the tunnel manually first so I understand exactly what Netbird is doing."

### Phase 4 — BGP with FRR

**Why:** Cloud routing, Kubernetes LoadBalancer services (metallb), and datacenter networking
all use BGP. It is the routing protocol of the internet and of modern k8s bare-metal setups.
Almost no platform engineer has set it up by hand.

- [ ] Two Docker containers running FRR (Free Range Routing)
- [ ] Configure eBGP session between them (different AS numbers)
  - [ ] `vtysh` — FRR's Cisco-like CLI
  - [ ] Configure `router bgp`, `neighbor`, `network` statements
  - [ ] Verify: `show bgp summary` — session Established, prefixes received
- [ ] Advertise a prefix on one side, verify it appears in the routing table on the other
- [ ] Connect to k8slab: configure MetalLB to use BGP mode
  - [ ] MetalLB BGPPeer — points at the FRR container
  - [ ] Advertise a LoadBalancer service IP via BGP
  - [ ] Verify: the service IP appears in the FRR routing table, is reachable
- [ ] Show what happens when a BGP session drops:
  - [ ] Kill the FRR process on one side
  - [ ] Watch route withdrawal — the prefix disappears from the routing table
  - [ ] Count convergence time: how long before traffic stops going to the withdrawn route

**Interview angle:** "BGP is a path-vector protocol — each router advertises prefixes with
an AS path. When MetalLB runs in BGP mode, it advertises the LoadBalancer IP from the
node's AS to the top-of-rack switch. Any router that receives the advertisement routes
traffic for that IP to that node. I set this up with FRR in the lab: two BGP peers, prefix
advertisement, and MetalLB integration. I also observed route withdrawal — when the FRR
session drops, the route disappears within the hold-time (default 90s) and traffic fails
over to other nodes advertising the same prefix."

### Phase 5 — Network policy deep dive

- [ ] Three-tier isolation in k8slab: monitoring namespace, app namespace, infra namespace
- [ ] Default-deny all ingress on all namespaces
- [ ] Explicit allows only: Prometheus → scrape all, ingress → app, app → infra
- [ ] Test each policy with `kubectl exec -- curl` — verify blocks and allows
- [ ] Cilium L7 policy: allow HTTP GET `/api/*` but block POST — iptables cannot do this
  - [ ] Write `CiliumNetworkPolicy` with HTTP method filter
  - [ ] Verify: GET works, POST returns 403 from Cilium (never reaches app)
- [ ] Show the Hubble flow log for a blocked request — kernel-level visibility

---

## securitylab/ — Supply chain and runtime security

**Goal:** Harden and audit the infrastructure that awslab and k8slab already run. Not a
standalone security "toy" — actual security tooling applied to real running systems.

**Dependency:** awslab and k8slab must be running. securitylab adds a security layer
on top of them.

**Why this matters:** "Security" in job descriptions means different things. Junior: knows
CVEs. Mid: runs scanners. Senior: designs the supply chain. Staff: builds the enforcement
layer. This lab covers all four. Supply chain security is the fastest-growing interview
topic in the post-SolarWinds, post-Log4j world.

### Phase 1 — Container image scanning

- [ ] Trivy scanning against every image in k8slab
  - [ ] `trivy image <image>` — CVE report with severity and fixed-in version
  - [ ] Integrate into Gitea Actions: `.gitea/workflows/scan.yaml` — blocks push on CRITICAL
  - [ ] Show: an image with a known CVE, the block, the fix (bump base image), the re-scan
- [ ] Grype as second scanner (different DB, catches different CVEs)
  - [ ] Compare Trivy vs Grype output on the same image — understand why they differ
- [ ] Scan the IaC itself: `tfsec` against awslab Terraform modules
  - [ ] Show findings: security group with open egress, S3 bucket without versioning
  - [ ] Fix each finding, document why it was flagged
- [ ] `kube-bench` against the k3s cluster — CIS Kubernetes benchmark
  - [ ] Run `kube-bench` — shows pass/fail per CIS control
  - [ ] Fix at least 3 failing controls, document what changed and why

**Interview angle:** "Every image build in the CI pipeline runs Trivy before the push step.
CRITICAL CVEs block the pipeline — the image doesn't reach the registry. We also run Grype
because the two databases don't overlap completely. For IaC, tfsec catches Terraform
misconfigs before apply — open security groups, missing encryption, public S3 buckets.
kube-bench runs on a schedule and reports CIS control drift — if someone loosens an RBAC
binding, it shows up in the next benchmark run."

### Phase 2 — Supply chain: SBOM and image signing

**Why:** After Log4Shell, "what exactly is in your container?" became a board-level question.
SBOM (Software Bill of Materials) is now required by US executive order for government
contractors. Cosign + Sigstore is how the industry answered: cryptographic proof that an
image came from a specific CI pipeline, not a tampered registry.

- [ ] Syft — generate SBOM for every image in k8slab
  - [ ] `syft <image> -o spdx-json` — SPDX format (the standard)
  - [ ] Attach SBOM to image as OCI attestation: `cosign attest --predicate sbom.json`
  - [ ] Verify the attestation: `cosign verify-attestation` — checks the signature chain
- [ ] Cosign — sign every image that passes the CI pipeline
  - [ ] `cosign generate-key-pair` — cosign.key (secret), cosign.pub (committed to repo)
  - [ ] Sign image after Trivy passes: `cosign sign --key cosign.key <image-digest>`
  - [ ] Verify at deploy time: `cosign verify --key cosign.pub <image>` — fails if unsigned
- [ ] Kyverno policy: block unsigned images in k8slab
  - [ ] `ClusterPolicy` — verifyImages rule, references cosign.pub
  - [ ] Test: deploy a signed image (succeeds), deploy an unsigned image (blocked at admission)
  - [ ] Show the admission webhook rejection event in `kubectl describe pod`
- [ ] Keyless signing with Sigstore (Fulcio + Rekor)
  - [ ] Sign using GitHub Actions OIDC token — no long-lived key
  - [ ] Verify against the Rekor transparency log — publicly auditable, tamper-evident
  - [ ] Explain: Fulcio issues short-lived cert, Rekor logs the signing event, cert expires

**Interview angle:** "Every image in our CI pipeline is signed with Cosign and has an SBOM
attached as an OCI attestation. A Kyverno policy at the admission webhook blocks any
unsigned image from being scheduled. If someone pushes a manually built image to the
registry, it fails admission because it has no Cosign signature. For keyless signing we use
the Sigstore stack — the CI job signs with its OIDC token, Fulcio issues a short-lived
cert, Rekor logs the event. There's no long-lived key to rotate or leak."

### Phase 3 — Runtime security with Falco

**Why:** Image scanning finds known CVEs in static images. Falco catches what scanners miss:
a process inside a running container doing something suspicious — spawning a shell, reading
/etc/passwd, making unexpected network connections. This is the difference between
vulnerability detection and threat detection.

- [ ] Falco — Helm ArgoCD app in k8slab (`cluster/infra/falco/`)
  - [ ] eBPF probe mode (no kernel module required in k3s)
  - [ ] Default ruleset enabled
- [ ] Custom rules for the platform:
  - [ ] Alert: shell spawned inside any container (`proc.name in (bash, sh, zsh)`)
  - [ ] Alert: sensitive file read (`/etc/shadow`, `/etc/passwd`, `/root/.ssh`)
  - [ ] Alert: unexpected outbound connection from ECS task in awslab (port not in allowlist)
  - [ ] Alert: privileged container started without the expected annotation
- [ ] Test each rule by triggering it:
  - [ ] `kubectl exec -it <pod> -- bash` — triggers shell-in-container alert
  - [ ] `kubectl exec <pod> -- cat /etc/shadow` — triggers sensitive-file alert
  - [ ] Verify: Falco log shows the event within 1 second
- [ ] Route Falco alerts to Grafana Loki — search for security events alongside app logs
- [ ] Build a Grafana dashboard: Falco alert volume by rule, by namespace, by pod

**Interview angle:** "Falco runs in the cluster as a DaemonSet with an eBPF probe — it
hooks into kernel system calls and evaluates rules without modifying any container. We have
a custom rule that fires if a shell is spawned inside any container. During an incident
where we suspected a compromised dependency, Falco showed us exactly which container, which
process, and what file it accessed — all before we could even look at the application logs.
Alerts feed into Loki so security events appear in the same timeline as application errors."

### Phase 4 — OPA/Rego policy library

**Why:** Kyverno (already in k8slab Phase 3) handles admission control with YAML policies.
OPA/Rego handles the harder cases: cross-resource policies, multi-cluster policy
distribution, authorization in non-Kubernetes contexts (Terraform, API gateways, CI gates).
Both are in the market; knowing the difference matters.

- [ ] OPA Gatekeeper — Helm ArgoCD app (alongside Kyverno)
  - [ ] Explain: Kyverno for simple rules (require labels, block latest tags)
  - [ ] OPA/Rego for complex logic (cross-reference ConfigMap, compute expressions)
- [ ] Write Rego policies:
  - [ ] Pod must not request more than 50% of node CPU (requires cross-resource lookup)
  - [ ] Ingress hostnames must match the namespace's allowed domain list (ConfigMap lookup)
  - [ ] Service accounts must not have wildcard verbs in ClusterRoles
- [ ] Conftest — run Rego policies against Terraform plan output
  - [ ] `terraform show -json plan.json | conftest test -`
  - [ ] Policy: no S3 bucket without versioning enabled
  - [ ] Policy: no security group with `0.0.0.0/0` ingress on port 22
  - [ ] Run in Gitea CI: blocks `make apply` if Terraform plan violates policy
- [ ] OPA in the Netbird context: write ACL rules as Rego, evaluate before network policy apply

**Interview angle:** "We use both Kyverno and OPA. Kyverno handles admission control for
the common cases — it's readable YAML and the dev team can understand policies without
learning Rego. OPA handles the complex cases: a policy that cross-references a ConfigMap
to look up a namespace's allowed ingress domains is one expression in Rego and impossible
to express in Kyverno's matcher syntax. We also run OPA via Conftest in the CI pipeline
against the Terraform plan — before any infrastructure change is applied, the plan is
validated against our security policies."

### Phase 5 — IAM audit and least privilege

- [ ] Audit awslab IAM policies with `iamlive`
  - [ ] Run `iamlive` in capture mode during `make deploy` — records every IAM call made
  - [ ] Output: minimal IAM policy that covers exactly what was used
  - [ ] Compare against current policy — find and remove excess permissions
- [ ] `aws-nuke` dry run against Ministack
  - [ ] Understand what would be destroyed — practice the incident response for "who provisioned this?"
  - [ ] Build a resource tagging policy: everything must have `Environment` and `ManagedBy` tags
  - [ ] Anything untagged = out-of-band provisioning = security finding
- [ ] CIS AWS Foundations Benchmark against awslab
  - [ ] CloudTrail enabled (map to Ministack equivalent)
  - [ ] S3 bucket public access blocked
  - [ ] Root account has MFA (document — cannot test in Ministack)
  - [ ] No access keys for root (document)
  - [ ] IAM password policy meets minimum requirements

---

## platformlab/ — Internal developer platform

**Goal:** Wrap the existing awslab and k8slab infrastructure in a developer-facing product
layer. Backstage as the IDP — service catalog, golden path templates, self-service
provisioning. The platform team's job is not just to run the infrastructure but to make
it accessible to the developers who use it.

**Dependency:** awslab and k8slab must be running. platformlab catalogs and surfaces them.

**Why this matters:** "Platform engineering" as a title is growing faster than any other
infrastructure role. The tools are Backstage, Crossplane, and port.io. Backstage is the
open-source standard. Understanding how to build a developer platform on top of working
infrastructure is a distinct skill from building the infrastructure itself.

### Phase 1 — Backstage IDP

- [ ] Backstage — deployed in k8slab via ArgoCD app (`cluster/apps/backstage/`)
  - [ ] SQLite backend for simplicity (Postgres for production-grade)
  - [ ] GitHub integration for auth (or Gitea OIDC — use the Dex instance from awslab)
  - [ ] Accessible via Cloudflare Tunnel: `platform.binarysquad.org`
- [ ] Initial catalog population:
  - [ ] Register all k8slab services as Backstage `Component` entities
    - [ ] ArgoCD, Grafana, Vault, Gitea, Prometheus, Tempo, Loki — each a catalog entry
    - [ ] Links to dashboards, runbooks, owner, SLO status
  - [ ] Register all awslab resources as `Resource` entities
    - [ ] ALB, ECS service, RDS, S3 buckets — each a catalog entry
    - [ ] Tags: environment (dev/staging), team, managed-by: terraform
  - [ ] `catalog-info.yaml` in every service repo — Backstage discovers automatically
- [ ] TechDocs: markdown docs rendered inside Backstage
  - [ ] Every module README becomes a Backstage TechDoc page
  - [ ] Runbooks from dblab available in Backstage UI — no separate docs site needed

**Interview angle:** "The platform catalog in Backstage is the single source of truth for
what services exist, who owns them, and how to reach them. Every service has a
catalog-info.yaml in its repo — Backstage discovers it automatically via GitHub integration.
We also pull in awslab resources as catalog entities using Backstage's AWS entity provider,
so a developer can see their ECS service, its health, and its ALB endpoint all in one place
without touching the AWS console."

### Phase 2 — Golden path templates

**Why:** Golden paths are the platform team's core product. Instead of every team solving
the same infra problem differently, the platform provides a template that encodes the right
answer. Templates should be opinionated, production-ready, and self-service.

- [ ] Template 1: "Create a new service" (the most common request)
  - [ ] Backstage Software Template — form in the UI
  - [ ] Inputs: service name, team, language (Go/Python), needs-db (yes/no)
  - [ ] Template creates:
    - [ ] Gitea repo with correct structure, `.gitea/workflows/`, `catalog-info.yaml`
    - [ ] Kubernetes manifests (Deployment, Service, HPA, PodDisruptionBudget)
    - [ ] ArgoCD Application pointing at the new repo
    - [ ] Grafana dashboard provisioned from a standard template
    - [ ] Registers the new service in Backstage catalog automatically
  - [ ] End result: developer fills out a form, gets a fully wired service in 2 minutes
- [ ] Template 2: "Request a database" (the second most common request)
  - [ ] Inputs: service name, db size (small/medium), environment (dev/staging)
  - [ ] Template creates a Terraform PR adding a new RDS module in awslab
  - [ ] PR goes through ArgoCD + Atlantis (or manual approval), resource is created
  - [ ] Connection string pushed to Vault, ExternalSecret created for the service
- [ ] Template 3: "Add monitoring to an existing service"
  - [ ] Inputs: service name, namespace, port, metrics-path
  - [ ] Template creates: ServiceMonitor, PrometheusRule (SLO alerts), Grafana dashboard
  - [ ] PR auto-approved if service already in catalog, manual review if new

**Interview angle:** "Our golden path for a new service is a Backstage template. The
developer picks a language and answers three questions. The template scaffolds the repo,
the Kubernetes manifests, the ArgoCD app, and the Grafana dashboard. The service is in
production configuration from day one — resource limits set, PodDisruptionBudget configured,
SLO alerts wired up. The platform team maintains the template; the dev team never has to
think about Helm charts or ArgoCD syntax."

### Phase 3 — Self-service infrastructure via Crossplane

**Why:** Backstage templates via Terraform PRs work but require a human approval step.
Crossplane lets developers provision cloud resources (RDS, S3, Redis) via Kubernetes
manifests — same GitOps workflow they already use for their services, no separate IaC
knowledge required. The platform team writes the XRD (composite resource definition),
developers consume it.

- [ ] Crossplane — Helm ArgoCD app in k8slab
  - [ ] AWS provider (pointed at Ministack endpoint)
  - [ ] Composition: `PostgreSQLInstance` XRD
    - [ ] Developer creates: `kubectl apply -f my-db.yaml` (10 lines)
    - [ ] Crossplane creates: RDS instance, subnet group, parameter group, secret in Vault
    - [ ] Developer gets: connection string via ExternalSecret, no knowledge of RDS config needed
  - [ ] Composition: `ObjectStoreBucket` XRD
    - [ ] Developer creates a bucket by applying a simple manifest
    - [ ] Crossplane creates S3 bucket with correct ACL, versioning, lifecycle policy
- [ ] RBAC: namespaced XRDs
  - [ ] Developers can claim a `PostgreSQLInstance` in their namespace
  - [ ] Platform team controls the composition (what RDS config is actually created)
  - [ ] No developer has direct AWS console access
- [ ] Integration with Backstage:
  - [ ] Crossplane resources appear in Backstage catalog as `Resource` entities
  - [ ] Developer can see their database, its status, and its connection info from Backstage

**Interview angle:** "Crossplane lets us give developers database-as-a-service without
exposing any AWS config. They apply a 10-line YAML file — name, size, environment.
Crossplane's composition translates that into an RDS instance with the correct subnet group,
parameter group, and security group config. The connection string lands in Vault via
an ExternalSecret — the developer's service picks it up the same way it picks up every
other secret. No AWS console access, no Terraform knowledge required. The platform team
owns the composition; the dev team owns the claim."

### Phase 4 — Platform metrics and reliability

**Why:** The platform team is also responsible for the reliability of the platform itself.
What are the SLOs for Backstage? For the Crossplane provisioner? For the Gitea Actions
runner? If these are slow or down, every developer is blocked.

- [ ] SLOs for platform services:
  - [ ] Backstage availability: 99.5% (internal tooling, not customer-facing)
  - [ ] Template execution success rate: > 98% (template failures block new service creation)
  - [ ] CI runner queue time: p95 < 2 minutes (slow CI is slow feedback loops)
- [ ] Platform-level Grafana dashboard:
  - [ ] Backstage request rate, error rate, latency
  - [ ] Crossplane provisioning success rate, provisioning time per resource type
  - [ ] Gitea Actions: queue depth, runner utilization, job failure rate
  - [ ] ArgoCD: sync success rate, sync duration, number of out-of-sync apps
- [ ] Error budget for the platform:
  - [ ] Platform-wide availability SLO: if Vault is down, all ESO syncs fail, all services fail
  - [ ] Dependency mapping: which platform failures cascade and how far
  - [ ] Chaos experiment: kill Vault, measure time to recovery, verify ESO retry behavior

**Interview angle:** "The platform team has SLOs too. If the Gitea Actions runner has a
p95 queue time of 8 minutes, that's 8 minutes of developer wait time on every PR. We track
it the same way we track application SLOs — PrometheusRule, error budget, burn rate alert.
The platform's reliability is a product decision: we publish it internally so dev teams
know what to expect and can build their release cadence around it."
