SHELL := /bin/bash
.ONESHELL:

ANSIBLE_DIR := ansible

ifneq (,$(wildcard ../.env))
  include ../.env
  export
endif

.PHONY: up down

## Start Ministack on homelab
up: _check-env _generate-inventory
	@echo ">>> Starting awslab..."
	cd $(ANSIBLE_DIR) && ansible-playbook provision.yaml
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Ministack is up at http://$(TARGET_HOST):4566"
	@echo ""
	@echo "  To configure your shell:"
	@echo "    source awslab/env.sh"
	@echo ""
	@echo "  Quick test:"
	@echo "    aws s3 ls"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

## Stop Ministack and clean homelab
down: _check-env _generate-inventory
	@echo ">>> Tearing down awslab..."
	cd $(ANSIBLE_DIR) && ansible-playbook teardown.yaml
	@echo "Done."

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
