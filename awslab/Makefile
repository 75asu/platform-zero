SHELL := /bin/bash
.ONESHELL:

ANSIBLE_DIR := ansible

ifneq (,$(wildcard ../.env))
  include ../.env
  export
endif

# ── AWS / Terraform env ────────────────────────────────────────────────────────
# These are exported to every recipe line. Source env.sh in your shell to get
# the same variables for ad-hoc aws CLI calls outside of Make.
export AWS_ENDPOINT_URL      = http://$(TARGET_HOST):4566
export AWS_DEFAULT_REGION    = us-east-1
export AWS_ACCESS_KEY_ID     = test
export AWS_SECRET_ACCESS_KEY = test
export AWS_PAGER             =
export MINIO_ENDPOINT_URL    = http://$(TARGET_HOST):9000

# Shared provider cache — one download per version, shared across all modules.
# Eliminates the parallel-download race and the 400 MB spike on every make clean.
export TF_PLUGIN_CACHE_DIR                          = $(HOME)/.terraform.d/plugin-cache
# Allow the shared cache even if it can't match the lock file exactly.
# darwin/arm64 hardlink race when parallelism > 1 causes mismatch errors.
export TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE = true

.PHONY: up down deploy teardown reset verify tf-dev tf-staging tf-all clean \
        _check-env _generate-inventory

# ── Primary targets ────────────────────────────────────────────────────────────

## Full stack up: start Ministack + MinIO on homelab, then apply all Terraform modules
deploy: up tf-all

## Full stack down: stop all containers and remove all volumes
teardown: down

## Wipe everything and rebuild from scratch.
## Equivalent to: teardown + clean + deploy
## Run this after pulling changes that add new modules or alter the backend.
reset: teardown clean deploy

# ── Stack lifecycle ────────────────────────────────────────────────────────────

## Start Ministack + MinIO on homelab via Ansible, then bootstrap state infrastructure
up: _check-env _generate-inventory
	@mkdir -p $(HOME)/.terraform.d/plugin-cache
	echo ">>> Starting awslab..."
	(cd $(ANSIBLE_DIR) && ansible-playbook provision.yaml)
	echo ">>> Bootstrapping state infrastructure..."
	aws dynamodb create-table \
	  --table-name platform-zero-tfstate-lock \
	  --attribute-definitions AttributeName=LockID,AttributeType=S \
	  --key-schema AttributeName=LockID,KeyType=HASH \
	  --billing-mode PAY_PER_REQUEST \
	  2>/dev/null || true
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  Ministack : http://$(TARGET_HOST):4566"
	echo "  MinIO     : http://$(TARGET_HOST):9000"
	echo "  MinIO UI  : http://$(TARGET_HOST):9001  (user: minioadmin / minioadmin)"
	echo ""
	echo "  Run: make verify   — smoke test all services"
	echo "  Run: make tf-all   — apply all Terraform modules"
	echo "  Run: make deploy   — up + tf-all in one step"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

## Stop all containers and volumes (Ministack, MinIO, Netbird, Dex)
down: _check-env _generate-inventory
	echo ">>> Tearing down awslab..."
	(cd $(ANSIBLE_DIR) && ansible-playbook teardown.yaml)
	echo "Done."

# ── Smoke test ─────────────────────────────────────────────────────────────────

## Verify Ministack, MinIO state bucket, and DynamoDB lock table are all reachable
verify: _check-env
	@echo "Checking Ministack..."
	@aws sts get-caller-identity > /dev/null 2>&1 && echo "  Ministack  OK" || (echo "  Ministack  FAIL"; exit 1)
	@echo "Checking MinIO state bucket..."
	@AWS_ACCESS_KEY_ID=minioadmin AWS_SECRET_ACCESS_KEY=minioadmin \
	  aws --endpoint-url=http://$(TARGET_HOST):9000 s3 ls s3://platform-zero-tfstate > /dev/null 2>&1 \
	  && echo "  MinIO      OK" || (echo "  MinIO      FAIL (run: make up)"; exit 1)
	@echo "Checking DynamoDB lock table..."
	@aws dynamodb describe-table --table-name platform-zero-tfstate-lock > /dev/null 2>&1 \
	  && echo "  DynamoDB   OK" || (echo "  DynamoDB   FAIL (run: make up)"; exit 1)
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

## Delete Terragrunt module caches and generated Lambda zips.
## Run after editing module source files, or before make reset.
clean:
	find terraform -name ".terragrunt-cache" -type d -exec rm -rf {} + 2>/dev/null || true
	find terraform -name ".terraform.lock.hcl" -not -path "*/modules/*" -delete 2>/dev/null || true
	find terraform/modules/lambda/handlers -name "*.zip" -delete 2>/dev/null || true
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
