# k8slab

A self-contained Kubernetes practice lab that boots a full GitOps platform in one command on a homelab machine. Covers the full SRE surface: cluster provisioning, GitOps, secrets, observability, security, CI/CD, and demo workloads.

## Stack

k3d + ArgoCD + Gitea + Vault + External Secrets Operator + kube-prometheus-stack + Loki + Tempo + Thanos + OpenTelemetry Collector + Falco + Gitea Actions + Cloudflare Tunnel

## How to run

**Prerequisites:** Docker on a Linux homelab machine. Ansible + kubectl on your local machine.

```bash
cp .env.example .env
# fill in TARGET_HOST, TARGET_USER, SSH_KEY_PATH and optional extras

make up      # provisions cluster, bootstraps Gitea + ArgoCD, activates GitOps loop
make status  # cluster health + ArgoCD sync status
make down    # full teardown, machine is clean
```

After `make up`, ArgoCD manages everything. To deploy changes:

```bash
# edit anything under cluster/
make push    # force-pushes to Gitea → ArgoCD reconciles within 3 min
```

## Two Git remotes

- `gitea` — ArgoCD's operational backend. Force-pushed on every manifest change (`make push`).
- `origin` (GitHub) — public portfolio history. Curated commits only (`make publish`).

Never mix them.

## Design notes

**App of Apps** - one root ArgoCD Application discovers all others. Sync waves enforce order: infra (Vault, ESO) before apps (monitoring, runners, workloads). A broken infra layer stops everything downstream.

**Secrets** - all credentials live in Vault. External Secrets Operator syncs them into Kubernetes Secrets on a schedule. Nothing sensitive in Git.
