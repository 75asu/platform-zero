# ansiblelab

> Operate apps on a fleet of VMs at scale -- without paying for a fleet.

One cheap VM becomes a **fleet of right-sized Linux nodes** using [Incus](https://linuxcontainers.org/incus/) system containers (full `systemd`, like small VMs -- not Docker). You manage them with Ansible over SSH, exactly as you would real servers. Everything is declarative and idempotent, and `make teardown` wipes back to bare Ubuntu with no residue.

It's a place to practice the real SRE craft -- right-sizing under load, rolling deploys, draining, failure injection, capacity planning -- on a fleet big enough to be interesting and cheap enough to leave running.

## Prerequisites

- **Your machine:** `ansible`, `gcloud` (for the GCP-VM path), and an SSH key.
- **A target:** a GCP VM (Spot is fine) or any Ubuntu 22.04+ host you can SSH to.
- Config lives in a gitignored `.env` (copy from `.env.example`) -- no secrets touch git.

## Quick start

```bash
cp .env.example .env     # fill in your VM coords (or point at any SSH host)
make up                  # start the VM, resolve its live IP, preflight SSH
make incus-setup         # install Incus: btrfs CoW pool, /16 bridge, kernel tuning
make topology            # create the named, right-sized fleet (db-01, cache-01, gitea-01)
make ssh                 # shell onto the VM (the fleet's hypervisor)
make down                # stop the VM -- billing stops; disk + fleet persist
```

Every step is idempotent -- re-run it and it converges. `make down` / `make up` preserves the whole fleet (containers auto-start on boot).

## Make targets

| Target | Does |
|---|---|
| `make up` / `make down` | start + connect / stop the VM (compute billing) |
| `make ssh` | open a shell on the VM |
| `make incus-setup` | install + tune Incus (idempotent) |
| `make topology` | converge the named, right-sized fleet |
| `make fleet FLEET=N` | spin up a flat N-node fleet (capacity testing) |
| `make fleet-down` | delete fleet containers (keep Incus) |
| `make teardown` | wipe Incus back to bare Ubuntu -- no residue |

## How it's wired

- **Right-sizing:** each node gets cgroup caps (`limits.cpu` / `limits.memory` / `limits.cpu.allowance`) so capacity is arithmetic, not guesswork.
- **Golden base image:** launches pin to a cached, offline-backed-up image -- rebuilds work even if the upstream image CDN is down.
- **Bastion management:** containers sit on a private `/16`; Ansible reaches them through the VM as an SSH jump host.
- **CoW storage:** a btrfs pool lets ~1,000+ containers share one base image (vs ~300 disk-bound on the default `dir` backend).

## Layout

```
ansible.cfg        tuned SSH multiplexing / forks / accept-new host keys
.env.example       VM coords + connection modes (copy to .env -- gitignored)
bin/               vm.sh (VM lifecycle) | render-inventory.sh (live-IP inventory)
roles/incus/       install Incus: btrfs pool, /16 bridge, kernel tuning for scale
playbooks/         incus | topology | fleet | fleet-down | teardown | preflight
Makefile           one command per step
```

## Where it's going

The fleet harness is built and hardened. The current exercise deploys a **full Gitea stack** (app + PostgreSQL + Redis, then shared storage and a load balancer) across the fleet -- to practice operating a real, stateful application at scale.
