#!/usr/bin/env bash
# ============================================================
# deploy/run-prod.sh — PRODUCTION RUNNER
# ============================================================
# Usage:
#   ./run-prod.sh              # up -d --build (default)
#   ./run-prod.sh down         # stop everything
#   ./run-prod.sh logs -f      # tail logs
#   ./run-prod.sh ps           # running containers
#   ./run-prod.sh restart      # restart services
# ============================================================

set -e
cd "$(dirname "$0")"

# ---- Sanity checks ----
if [ ! -f "docker-compose.prod.yml" ]; then
    echo "❌ Missing docker-compose.prod.yml"
    exit 1
fi
if [ ! -f ".env.prod" ]; then
    echo "❌ Missing .env.prod"
    exit 1
fi

# ---- Default to "up -d --build" if no args ----
if [ $# -eq 0 ]; then
    exec docker compose \
        -f docker-compose.yml \
        -f docker-compose.prod.yml \
        --env-file .env.prod \
        up -d --build
fi

exec docker compose \
    -f docker-compose.yml \
    -f docker-compose.prod.yml \
    --env-file .env.prod \
    "$@"