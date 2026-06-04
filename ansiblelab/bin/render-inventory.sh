#!/usr/bin/env bash
# Render inventory/hosts.yaml from the connection vars in .env.
#
# Supports two modes (see .env.example):
#   1) ssh_config alias  -- TARGET_HOST=<alias>; user/key/jump come from ~/.ssh/config
#   2) explicit          -- TARGET_HOST=<ip> + TARGET_USER/SSH_KEY_PATH [+ TARGET_PORT/SSH_JUMP]
#
# Set ENV_FILE to point at a different env file (used by tests). Defaults to .env.
set -euo pipefail

cd "$(dirname "$0")/.."                      # -> ansiblelab/
ENV_FILE="${ENV_FILE:-.env}"
if [ -f "$ENV_FILE" ]; then
  set -a; . "$ENV_FILE"; set +a
fi

# If a GCP VM is configured and TARGET_HOST isn't set explicitly, resolve its
# LIVE external IP from gcloud (a Spot VM's IP changes on every stop/start, so we
# never hardcode it). Plain SSH hosts (homelab, etc.) still work via TARGET_HOST.
if [ -z "${TARGET_HOST:-}" ] && [ -n "${GCP_VM_NAME:-}" ]; then
  TARGET_HOST="$(gcloud compute instances describe "$GCP_VM_NAME" \
    --project "${GCP_PROJECT:?set GCP_PROJECT in .env}" --zone "${GCP_ZONE:?set GCP_ZONE in .env}" \
    --format='value(networkInterfaces[0].accessConfigs[0].natIP)' 2>/dev/null || true)"
  [ -z "$TARGET_HOST" ] && { echo "ERROR: '$GCP_VM_NAME' has no external IP -- is it running? (make vm-start)"; exit 1; }
fi
: "${TARGET_HOST:?Set TARGET_HOST in .env (ssh alias or IP), or set GCP_VM_NAME/GCP_PROJECT/GCP_ZONE to resolve it live}"
HOST_NAME="${LAB_HOST_NAME:-ansiblelab}"
mkdir -p inventory

# Per-host SSH safety + resilience args. -F ~/.ssh/config so ssh_config aliases
# (and your hardened Host blocks) are honored even under Ansible.
ssh_args=(
  -F "$HOME/.ssh/config"
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=15
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=4
)
[ -n "${SSH_JUMP:-}" ] && ssh_args+=( -o "ProxyJump=$SSH_JUMP" )
SSH_COMMON="${ssh_args[*]}"

{
  echo "# Auto-generated from $ENV_FILE by bin/render-inventory.sh -- do not edit by hand."
  echo "all:"
  echo "  hosts:"
  echo "    ${HOST_NAME}:"
  echo "      ansible_host: ${TARGET_HOST}"
  [ -n "${TARGET_USER:-}" ]    && echo "      ansible_user: ${TARGET_USER}"
  [ -n "${TARGET_PORT:-}" ]    && echo "      ansible_port: ${TARGET_PORT}"
  [ -n "${SSH_KEY_PATH:-}" ]   && echo "      ansible_ssh_private_key_file: ${SSH_KEY_PATH}"
  echo "      ansible_python_interpreter: auto_silent"
  echo "      ansible_ssh_common_args: '${SSH_COMMON}'"
} > inventory/hosts.yaml

echo "wrote inventory/hosts.yaml  (host: ${HOST_NAME} -> ${TARGET_HOST})"
