# platform-zero Makefile
#
#   make up       — cluster + Gitea + ArgoCD + GitOps, credentials written to .env
#   make down     — full teardown, machine is clean
#   make restart  — down then up
#   make status   — cluster health + ArgoCD sync status
#
# ── Git remotes ───────────────────────────────────────────────────────────────
#
#   Two remotes, two purposes — never mix them:
#
#   origin  (GitHub)  — public portfolio history. Curated commits only.
#                       Push manually with: make publish
#                       Never force-pushed. Never automated.
#
#   gitea   (Gitea)   — ArgoCD's Git backend. main → cluster branch (force).
#                       Push after every manifest change with: make push
#                       History here is operational, not portfolio.
#
#   make push         — git push gitea main:cluster --force
#                       Use this whenever you change cluster/ or ansible/.
#                       ArgoCD detects the diff and reconciles within 3 min.
#
#   make publish      — git push origin main
#                       Use this only when commits are clean and ready to be public.
#                       Requires explicit confirmation prompt before pushing.

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

.PHONY: up down restart status push publish

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

## Push manifests to Gitea → ArgoCD syncs (daily driver for cluster changes)
push: _check-env _check-kubeconfig
	@echo ">>> Pushing to Gitea (main → cluster)..."
	@git push gitea main:cluster --force
	@echo ""
	@echo "  ArgoCD will reconcile within 3 min."
	@echo "  Run 'make status' to watch convergence."

## Push to GitHub — curated public history only (requires confirmation)
publish:
	@echo ">>> You are about to push to GitHub (origin/main)."
	@echo "    This is the public portfolio repo. Commits will be visible."
	@echo ""
	@read -p "    Are the commits clean and ready to publish? [y/N] " confirm && \
	  [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] || \
	  (echo "Aborted." && exit 1)
	@git push origin main
	@echo "Published to GitHub."

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
