SHELL := /bin/bash
.ONESHELL:

ANSIBLE_DIR := ansible

ifneq (,$(wildcard ../.env))
  include ../.env
  export
endif

# AWS / Terraform env — inherited by every recipe line, no need to source env.sh
export AWS_ENDPOINT_URL     = http://$(TARGET_HOST):4566
export AWS_DEFAULT_REGION   = us-east-1
export AWS_ACCESS_KEY_ID    = test
export AWS_SECRET_ACCESS_KEY = test
export AWS_PAGER            =
export MINIO_ENDPOINT_URL   = http://$(TARGET_HOST):9000

.PHONY: up down deploy teardown tf-dev tf-staging tf-all clean

## Full stack up: start containers + apply all environments
deploy: up tf-all

## Full stack down: stop containers
## Ministack is in-memory and MinIO data lives in the container layer,
## so docker compose down wipes everything — no terraform destroy needed.
teardown: down

## Start Ministack + MinIO on homelab, then create the DynamoDB lock table
up: _check-env _generate-inventory
	echo ">>> Starting awslab..."
	(cd $(ANSIBLE_DIR) && ansible-playbook provision.yaml)
	echo ">>> Creating DynamoDB state lock table..."
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
	echo "  To configure your shell:"
	echo "    source awslab/env.sh"
	echo ""
	echo "  Quick test:"
	echo "    aws s3 ls"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

## Stop all containers (Ministack + MinIO)
down: _check-env _generate-inventory
	echo ">>> Tearing down awslab..."
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

## Delete all Terragrunt module caches — run after editing module source files
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
