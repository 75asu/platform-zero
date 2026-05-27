SHELL := /bin/bash
.ONESHELL:

ANSIBLE_DIR := ansible

ifneq (,$(wildcard ../.env))
  include ../.env
  export
endif

# ── GCP / Terraform env ────────────────────────────────────────────────────────
export MINISKY_ENDPOINT          = http://$(TARGET_HOST):8082
export MINISKY_DASHBOARD         = http://$(TARGET_HOST):8083
export MINIO_ENDPOINT_URL        = http://$(TARGET_HOST):9002
export GOOGLE_OAUTH_ACCESS_TOKEN = minisky-fake-token
export CLOUDSDK_CORE_PROJECT     = gcplab-dev

# Shared provider cache — same pattern as awslab.
export TF_PLUGIN_CACHE_DIR                            = $(HOME)/.terraform.d/plugin-cache
export TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE = true

.PHONY: up down deploy teardown reset verify tf-dev tf-staging tf-all clean \
        _check-env _generate-inventory

# ── Primary targets ────────────────────────────────────────────────────────────

## Full deploy: homelab up + apply all Terraform modules
deploy: up tf-all

## Alias for down
teardown: down

## Nuke everything and rebuild from scratch.
reset: teardown clean deploy

# ── Stack lifecycle ────────────────────────────────────────────────────────────

## Build MiniSky image + start MiniSky, MinIO, and nginx proxy on homelab via Ansible.
## nginx proxy rewrites Host headers per port so the Google Terraform provider
## can point directly at the homelab IP — no /etc/hosts overrides needed.
up: _check-env _generate-inventory
	@mkdir -p $(HOME)/.terraform.d/plugin-cache
	echo ">>> Starting gcplab..."
	(cd $(ANSIBLE_DIR) && ansible-playbook provision.yaml)
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  MiniSky API  : http://$(TARGET_HOST):8082"
	echo "  MiniSky UI   : http://$(TARGET_HOST):8083"
	echo "  MinIO        : http://$(TARGET_HOST):9002"
	echo "  MinIO UI     : http://$(TARGET_HOST):9003  (user: minioadmin / minioadmin)"
	echo "  Proxy ports  : $(TARGET_HOST):8090-8099 (storage/iam/pubsub/container/bigquery/...)"
	echo ""
	echo "  Next: make verify   ← smoke test"
	echo "  Then: make tf-all   ← apply all Terraform modules"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

## Stop all containers and volumes (MiniSky, MinIO, nginx proxy)
down: _check-env _generate-inventory
	echo ">>> Tearing down gcplab..."
	(cd $(ANSIBLE_DIR) && ansible-playbook teardown.yaml)
	echo "Done."

# ── Smoke test ─────────────────────────────────────────────────────────────────

## Verify MiniSky proxy and MinIO state bucket are reachable
verify: _check-env
	@echo "Checking MiniSky via proxy (storage port 8090)..."
	@curl -sf "http://$(TARGET_HOST):8090/storage/v1/b?project=gcplab-dev" > /dev/null 2>&1 \
	  && echo "  MiniSky proxy  OK" || (echo "  MiniSky proxy  FAIL (run: make up)"; exit 1)
	@echo "Checking MinIO state bucket..."
	@AWS_ACCESS_KEY_ID=minioadmin AWS_SECRET_ACCESS_KEY=minioadmin \
	  aws --endpoint-url=http://$(TARGET_HOST):9002 s3 ls s3://platform-zero-gcp-tfstate > /dev/null 2>&1 \
	  && echo "  MinIO          OK" || (echo "  MinIO          FAIL (run: make up)"; exit 1)
	@echo ""
	@echo "All services reachable. Ready for: make tf-all"

# ── Terraform ─────────────────────────────────────────────────────────────────

## Apply dev environment only (all modules under live/dev/)
tf-dev: _check-env
	cd terraform/live/dev && TG_NON_INTERACTIVE=true terragrunt run --all --parallelism 1 -- apply -auto-approve

## Apply staging environment only (all modules under live/staging/)
tf-staging: _check-env
	cd terraform/live/staging && TG_NON_INTERACTIVE=true terragrunt run --all --parallelism 1 -- apply -auto-approve

## Apply all environments (dev + staging) in dependency order
tf-all: _check-env
	cd terraform/live && TG_NON_INTERACTIVE=true terragrunt run --all --parallelism 1 -- apply -auto-approve

# ── Cache management ───────────────────────────────────────────────────────────

## Delete Terragrunt module caches and lock files
clean:
	find terraform -name ".terragrunt-cache" -type d -exec rm -rf {} + 2>/dev/null || true
	find terraform -name ".terraform.lock.hcl" -not -path "*/modules/*" -delete 2>/dev/null || true
	echo "Cache cleared."

# ── Internal ───────────────────────────────────────────────────────────────────

_check-env:
	@missing=(); \
	for var in TARGET_HOST TARGET_USER SSH_KEY_PATH; do \
	  if [[ -z "$${!var}" ]]; then missing+=("$$var"); fi; \
	done; \
	if [[ $${#missing[@]} -gt 0 ]]; then \
	  echo "ERROR: missing required variables: $${missing[*]}"; \
	  echo "Copy .env.example to ../.env and fill in the values."; \
	  exit 1; \
	fi

_generate-inventory:
	@envsubst < $(ANSIBLE_DIR)/inventory/hosts.yaml.tpl \
	  > $(ANSIBLE_DIR)/inventory/hosts.yaml
