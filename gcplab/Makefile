SHELL := /bin/bash
.ONESHELL:

ANSIBLE_DIR := ansible

ifneq (,$(wildcard ../.env))
  include ../.env
  export
endif

# GCP / Terraform env — inherited by every recipe line, no need to source env.sh
export MINISKY_ENDPOINT     = http://$(TARGET_HOST):8082
export MINISKY_DASHBOARD    = http://$(TARGET_HOST):8083
export MINIO_ENDPOINT_URL   = http://$(TARGET_HOST):9002
export GOOGLE_OAUTH_ACCESS_TOKEN = minisky-fake-token
export CLOUDSDK_CORE_PROJECT     = gcplab-dev

.PHONY: up down deploy teardown tf-dev tf-staging tf-all clean

## Full stack up: install MiniSky + start containers + apply all environments
deploy: up tf-all

## Full stack down: stop MiniSky + containers
teardown: down

## Install MiniSky binary on homelab + start MinIO
up: _check-env _generate-inventory
	echo ">>> Starting gcplab..."
	(cd $(ANSIBLE_DIR) && ansible-playbook provision.yaml)
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  MiniSky API : http://$(TARGET_HOST):8082"
	echo "  MiniSky UI  : http://$(TARGET_HOST):8083"
	echo "  MinIO       : http://$(TARGET_HOST):9002"
	echo "  MinIO UI    : http://$(TARGET_HOST):9003  (user: minioadmin / minioadmin)"
	echo ""
	echo "  To configure your shell:"
	echo "    source gcplab/env.sh"
	echo ""
	echo "  Quick test:"
	echo "    curl http://$(TARGET_HOST):8082/healthz"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

## Stop MiniSky + remove all containers
down: _check-env _generate-inventory
	echo ">>> Tearing down gcplab..."
	(cd $(ANSIBLE_DIR) && ansible-playbook teardown.yaml)
	echo "Done."

## Apply dev environment (all modules under live/dev/)
tf-dev: _check-env
	cd terraform/live/dev && TG_NON_INTERACTIVE=true terragrunt run --all -- apply -auto-approve

## Apply staging environment (all modules under live/staging/)
tf-staging: _check-env
	cd terraform/live/staging && TG_NON_INTERACTIVE=true terragrunt run --all -- apply -auto-approve

## Apply all environments
tf-all: _check-env
	cd terraform/live && TG_NON_INTERACTIVE=true terragrunt run --all -- apply -auto-approve

## Delete all Terragrunt module caches
clean:
	find terraform -name ".terragrunt-cache" -type d -exec rm -rf {} + 2>/dev/null || true
	find terraform -name ".terraform.lock.hcl" -not -path "*/modules/*" -delete 2>/dev/null || true
	echo "Cache cleared."

## ── Internal targets ─────────────────────────────────────────────────────────

_check-env:
	@missing=(); \
	for var in TARGET_HOST TARGET_USER SSH_KEY_PATH; do \
	  if [[ -z "$${!var}" ]]; then missing+=("$$var"); fi; \
	done; \
	if [[ $${#missing[@]} -gt 0 ]]; then \
	  echo "ERROR: missing required variables: $${missing[*]}"; \
	  echo "Copy .env.example to .env and fill in the values."; \
	  exit 1; \
	fi

_generate-inventory:
	@envsubst < $(ANSIBLE_DIR)/inventory/hosts.yaml.tpl \
	  > $(ANSIBLE_DIR)/inventory/hosts.yaml
