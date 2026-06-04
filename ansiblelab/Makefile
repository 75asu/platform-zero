SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help
.PHONY: help up down ssh vm-start vm-stop vm-status vm-ip autostop connect inventory print-inventory incus-setup fleet fleet-down teardown topology

help: ## show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n",$$1,$$2}'

# -- daily driver -------------------------------------------------------------
up: vm-start connect ## start the VM, render its live IP, preflight  (come + connect)
down: vm-stop ## stop the VM -- billing stops, disk kept  (close + leave)
ssh: ## start if needed, then open a shell on the VM
	@bin/vm.sh ssh

# -- GCP VM lifecycle ---------------------------------------------------------
vm-start: ## start the GCP lab VM (Spot)
	@bin/vm.sh start
vm-stop: ## stop the GCP lab VM (billing stops, disk persists)
	@bin/vm.sh stop
vm-status: ## VM status + current external IP
	@bin/vm.sh status
vm-ip: ## print the VM's current external IP
	@bin/vm.sh ip
autostop: ## attach a daily auto-stop schedule (cost guardrail)
	@bin/vm.sh autostop

# -- Incus fleet (the lab itself; all declarative + idempotent) ---------------
incus-setup: inventory ## install + initialize Incus on the target (idempotent)
	@ansible-playbook playbooks/incus.yaml
fleet: inventory ## converge to FLEET=N containers (default in group_vars/all.yaml)
	@ansible-playbook playbooks/fleet.yaml $(if $(FLEET),-e fleet_count=$(FLEET),)
topology: inventory ## create the named, right-sized Gitea fleet (exec-bootstrap: sshd + key)
	@set -a; [ -f .env ] && . ./.env; set +a; \
	key="$${SSH_KEY_PATH/#\~/$$HOME}.pub"; \
	[ -f "$$key" ] || { echo "ERROR: public key not found: $$key (set SSH_KEY_PATH in .env)"; exit 1; }; \
	ansible-playbook playbooks/topology.yaml -e "{\"lab_ssh_pubkey\": \"$$(cat "$$key")\"}"
fleet-down: inventory ## delete the lab containers (keep Incus installed)
	@ansible-playbook playbooks/fleet-down.yaml
teardown: inventory ## WIPE: containers + Incus + repo/keys/data -- no residue
	@ansible-playbook playbooks/teardown.yaml

# -- connection (works for the VM, the homelab, any SSH host) -----------------
inventory: ## render inventory/hosts.yaml from .env (live IP when a GCP VM is set)
	@bin/render-inventory.sh
connect: inventory ## preflight: verify SSH + Python + sudo on the target
	@set -a; [ -f .env ] && . ./.env || true; set +a; \
	extra=; [ -n "$${BECOME_PASS:-}" ] && extra="-e ansible_become_password=$$BECOME_PASS"; \
	ansible-playbook playbooks/preflight.yaml $$extra
print-inventory: inventory ## print the rendered inventory
	@cat inventory/hosts.yaml
