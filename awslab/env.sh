#!/usr/bin/env bash
# Source this file to point your local AWS CLI and Terraform at Ministack + MinIO.
#   source awslab/env.sh
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

export AWS_ENDPOINT_URL=http://${TARGET_HOST}:4566
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_PAGER=""

export MINIO_ENDPOINT_URL=http://${TARGET_HOST}:9000

echo "→ awslab env set"
echo "  Ministack : http://${TARGET_HOST}:4566"
echo "  MinIO     : http://${TARGET_HOST}:9000  (console: :9001)"
echo ""
echo "  Quick test: aws s3 ls"
