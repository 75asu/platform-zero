# platform-zero

> Infrastructure that actually runs -- production patterns, real tools, a machine you control. Not diagrams, not "deploy to a managed service and call it done."
>
> If platform-zero is running, everything in it was built by hand and is working correctly.

Each lab is self-contained: clone it, point it at a machine, `make up`, break it, `make down`. **No secrets ever touch the repo** -- every `.env` is gitignored.

## Labs

| Lab | What it is | Start |
|-----|-----------|-------|
| [**k8slab**](k8slab/README.md) | Blank Linux box → full SRE platform: k3s, ArgoCD app-of-apps (Gitea backend), Vault + ESO, Cloudflare Tunnel, LGTM observability, Gitea Actions CI | `cd k8slab && make up` |
| [**awslab**](awslab/README.md) | 17 Terraform/Terragrunt modules against a self-hosted AWS emulator (Ministack) -- same code as real AWS | `cd awslab && make deploy` |
| [**gcplab**](gcplab/README.md) | 7 Terraform/Terragrunt modules against a self-hosted GCP emulator (MiniSky) | `cd gcplab && make deploy` |
| [**ansiblelab**](ansiblelab/README.md) | One cheap VM → a fleet of right-sized Incus nodes, Ansible-managed over SSH -- practice operating apps on VMs at scale | `cd ansiblelab && make up` |

Each lab's README has its stack, prerequisites, and walkthrough.

## Prerequisites

- **Your machine:** `brew install ansible kubectl helm awscli` + an SSH key
- **A target machine:** Linux (Ubuntu 22.04+), 2+ vCPU / 8 GB+ RAM / 40 GB+ disk, Docker, SSH access
- Per-lab config lives in that lab's gitignored `.env` (copy from `.env.example`)

## Conventions

- **GitOps:** after bootstrap, cluster state changes only via `git push` -- never `kubectl apply`.
- **No secrets in git:** every `.env` is gitignored; credentials stay on your machine.

## License

[Apache-2.0](LICENSE) © 2026 Asutosh Panda
