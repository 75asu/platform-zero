# platform-zero Makefile
#
#   make up       — cluster + Gitea + ArgoCD + GitOps, credentials written to .env
#   make down     — full teardown, machine is clean
#   make restart  — down then up
#   make status   — cluster health + ArgoCD sync status

SHELL := /bin/bash
.ONESHELL:

# ── Load .env ────────────────────────────────────────────────────────────────
ifneq (,$(wildcard .env))
  include .env
  export
endif

# ── Derived values ────────────────────────────────────────────────────────────
ANSIBLE_DIR := ansible
KUBECONFIG  := $(shell pwd)/kubeconfig.yaml
KUBECTL     := kubectl --kubeconfig=$(KUBECONFIG)

# ── Targets ───────────────────────────────────────────────────────────────────

.PHONY: up down restart status

## Cluster + Gitea + ArgoCD + GitOps handoff — one command
up: _check-env _check-deps _generate-inventory
	@echo ">>> Bringing up platform-zero..."
	cd $(ANSIBLE_DIR) && ansible-playbook setup.yaml
	set -a && source $(CURDIR)/.env && set +a
	cd $(ANSIBLE_DIR) && ansible-playbook activate.yaml
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  platform-zero is up."
	@echo ""
	@echo "  ArgoCD:  http://$(SERVER_IP):$(ARGOCD_NODEPORT)"
	@echo "  Gitea:   http://$(SERVER_IP):$(GITEA_NODEPORT)"
	@echo ""
	@echo "  Credentials written to .env"
	@echo "  kubectl: export KUBECONFIG=$(KUBECONFIG)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

## Full teardown — cluster gone, machine untouched
down: _check-env _generate-inventory
	@echo ">>> Tearing down..."
	cd $(ANSIBLE_DIR) && ansible-playbook teardown.yaml
	@rm -f $(KUBECONFIG)
	@echo "Done."

## Teardown then bring up fresh
restart: down up

## Cluster and ArgoCD health
status: _check-env
	@echo "=== Nodes ==="
	$(KUBECTL) get nodes -o wide
	@echo ""
	@echo "=== ArgoCD Apps ==="
	$(KUBECTL) get applications -n argocd 2>/dev/null || echo "ArgoCD not yet deployed"
	@echo ""
	@echo "=== All Pods ==="
	$(KUBECTL) get pods -A

# ── Internal ──────────────────────────────────────────────────────────────────

.PHONY: _check-env _check-deps _check-kubeconfig _generate-inventory

_generate-inventory:
	@envsubst < $(ANSIBLE_DIR)/inventory/hosts.yaml.tpl \
		> $(ANSIBLE_DIR)/inventory/hosts.yaml

_check-deps:
	@which helm > /dev/null 2>&1 || \
		(echo "ERROR: helm not installed. Run: brew install helm" && exit 1)
	@ansible-galaxy collection install -r $(ANSIBLE_DIR)/requirements.yaml

_check-kubeconfig:
	@test -f $(KUBECONFIG) || \
		(echo "ERROR: kubeconfig.yaml not found. Run 'make up' first." && exit 1)

_check-env:
	@missing=0; \
	for var in TARGET_HOST TARGET_USER SSH_KEY_PATH SERVER_IP \
	           GITEA_ADMIN_EMAIL REPO_NAME GIT_USER_NAME GIT_USER_EMAIL; do \
	  if [ -z "$${!var}" ]; then \
	    echo "ERROR: $$var is not set. Check your .env file."; \
	    missing=1; \
	  fi; \
	done; \
	if [ $$missing -eq 1 ]; then exit 1; fi
