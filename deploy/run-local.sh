#!/usr/bin/env bash
# deploy/run-local.sh
set -e
cd "$(dirname "$0")"
exec docker compose \
  -f docker-compose.yml \
  -f docker-compose.dev.yml \
  --env-file .env.local \
  "${@:-up}"