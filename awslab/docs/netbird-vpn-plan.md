# Netbird VPN Layer — Plan

Zero-trust network segmentation for awslab. Nothing reachable by raw IP.
All services behind the Netbird mesh. Dev and staging isolated at network layer.
VPN topology managed by Terraform alongside the AWS resources it protects.

---

## Why Netbird over Headscale

- Official Terraform provider (`netbirdio/netbird`) — ACL policies as IaC
- Built-in dashboard — visibility into mesh without extra tooling
- Enterprise features: device posture, audit logs, group-based access
- Self-hosted, no external accounts, unlimited nodes

---

## Target Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Netbird mesh                          │
│                                                          │
│  [Laptop]                  [Homelab]                     │
│  peer: engineer            peer: infra-node              │
│  group: engineers          ┌──────────────────────┐      │
│                            │ Netbird mgmt server  │      │
│                            │ Ministack (dev)  ─── │ peer: dev-infra
│                            │ Ministack (staging)─ │ peer: staging-infra
│                            │ MinIO            ─── │ peer: minio
│                            └──────────────────────┘      │
│                                                          │
│  ACL policy (Terraform-managed):                         │
│  engineers     → dev-infra     : tcp 4566  ✅            │
│  engineers     → staging-infra : tcp 4566  ✅            │
│  engineers     → minio         : tcp 9000  ✅            │
│  dev-infra     → staging-infra : BLOCKED   ❌            │
│  staging-infra → dev-infra     : BLOCKED   ❌            │
└─────────────────────────────────────────────────────────┘
```

No host port bindings (Phase 5). `terraform apply` only works when enrolled
in the mesh because the MinIO state backend is behind the VPN.

---

## Key Patterns to Implement

**1. Containers as individual Netbird peers**
Each service (Ministack-dev, Ministack-staging, MinIO) gets its own Netbird
identity and group tag — not the host. More granular than host-level VPN.
Same pattern as microservices in prod.

**2. Ephemeral setup keys via Terraform**
```hcl
resource "netbird_setup_key" "dev_ministack" {
  name       = "ministack-dev"
  type       = "one_off"      # expires after one use
  group_ids  = [netbird_group.dev_infra.id]
  expires_in = "1h"
}
```
Container starts → uses key to enroll → key expires.
Mirrors prod pattern: auto-scaling VMs / robots auto-join on first boot.

**3. ACL policies as Terraform code**
```hcl
resource "netbird_policy" "engineers_to_dev" {
  name    = "engineers-to-dev-infra"
  enabled = true

  rule {
    sources      = [netbird_group.engineers.id]
    destinations = [netbird_group.dev_infra.id]
    protocol     = "tcp"
    ports        = ["4566"]
    action       = "accept"
  }
}
```
Network security reviewed in Git like any other infra change.

**4. Dev/staging isolation at the network layer**
Two Ministack instances, same host, blocked from each other in Netbird ACL.
Dev Terraform cannot reach staging state backend — enforced at network level,
not just by convention.

**5. Enrollment before provisioning in `make deploy`**
```
make deploy
  → Ansible: start Netbird management server
  → Ansible: generate ephemeral setup keys via Netbird API
  → Ansible: start service containers with setup keys (auto-enroll)
  → Terraform: apply Netbird ACL policies (groups, rules)
  → Terraform: apply AWS resources via Ministack
               (only reachable now — laptop must be enrolled)
```

---

## Build Phases

| Phase | What gets built | Status |
|-------|----------------|--------|
| 1 — Netbird server | Netbird mgmt + signal + Dex OIDC in docker-compose | ✅ done |
| 2 — Ansible enrollment | Homelab auto-enrolls on `make up` via setup key + Dex password grant | ✅ done |
| 3 — Service peers | Ministack-dev, Ministack-staging, MinIO as individual peers | planned |
| 4 — Terraform ACL | `netbird_group`, `netbird_policy` resources | planned |
| 5 — Port lockdown | Remove host port bindings, bind to Netbird mesh IP only | planned |
| 6 — Staging isolation | Separate Ministack instance, blocked by ACL from dev | planned |

### Phase 1 detail (done)
- `docker-compose.yml`: netbird-signal, netbird-mgmt, netbird-dashboard, dex, dex-init, netbird-mgmt-init
- Dex: OIDC issuer at `http://{HOST}:5556/dex`, static password user `admin@awslab.local`
- Netbird management: wired to Dex for auth, SQLite state, signal on port 10000
- Docker networking: server-to-server via Docker hostnames, browser-facing via Tailscale IP
- Quoted heredoc + sed pattern for `TARGET_HOST` injection (avoids Docker Compose variable substitution in heredoc content)

### Phase 2 detail (done)
- Ansible provision.yaml: installs netbird agent on homelab host
- Gets Dex `id_token` via password grant (username: admin@awslab.local)
- Creates reusable setup key via Netbird management API (`Bearer {id_token}`)
- Clears stale daemon state (`rm -rf /var/lib/netbird/`), re-enrolls with new key
- Verify: `netbird status` shows `Management: Connected` + `Signal: Connected`

---

## Terraform Resources Used (Phase 4)

- `netbird_setup_key` — ephemeral enrollment keys per service
- `netbird_group` — engineers, dev-infra, staging-infra, minio
- `netbird_policy` — access rules between groups
- Provider: `registry.terraform.io/providers/netbirdio/netbird`

---

## What This Demonstrates

- Zero-trust network segmentation on a local lab
- Automated machine enrollment (ephemeral keys, no manual steps)
- VPN topology as IaC — same Git workflow as AWS resources
- Environment isolation enforced at the network layer
- State backend behind VPN — you cannot run Terraform without mesh access
