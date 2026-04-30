#!/usr/bin/env bash
# Source this file to point your local gcloud CLI and Terraform at MiniSky + MinIO.
#   source gcplab/env.sh
#
# Requires TARGET_HOST to be set in .env — the Makefile exports it automatically.
# If running manually: export TARGET_HOST=<homelab-ip> before sourcing.

if [[ -z "$TARGET_HOST" ]]; then
  DOTENV="$(dirname "${BASH_SOURCE[0]}")/../.env"
  if [[ -f "$DOTENV" ]]; then
    set -a && source "$DOTENV" && set +a
  else
    echo "ERROR: TARGET_HOST is not set and no .env found at $DOTENV"
    return 1
  fi
fi

export MINISKY_ENDPOINT=http://${TARGET_HOST}:8082
export MINISKY_DASHBOARD=http://${TARGET_HOST}:8083
export MINIO_ENDPOINT_URL=http://${TARGET_HOST}:9002

# Google provider picks up GOOGLE_OAUTH_ACCESS_TOKEN as a bearer token.
# MiniSky does not enforce auth — any non-empty value works.
export GOOGLE_OAUTH_ACCESS_TOKEN=minisky-fake-token

# gcloud CLI emulator target (for gsutil / gcloud storage commands)
export CLOUDSDK_API_ENDPOINT_OVERRIDES_STORAGE=${MINISKY_ENDPOINT}/storage/v1/
export CLOUDSDK_CORE_PROJECT=gcplab-dev

echo "→ gcplab env set"
echo "  MiniSky API : ${MINISKY_ENDPOINT}"
echo "  MiniSky UI  : ${MINISKY_DASHBOARD}"
echo "  MinIO       : ${MINIO_ENDPOINT_URL}  (console: :9003)"
echo ""
echo "  Quick test: curl ${MINISKY_ENDPOINT}/healthz"
