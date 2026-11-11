#!/usr/bin/env bash
# ============================================================
# SevaNext — PRODUCTION RUNNER (Linux server)
# File: deploy/run-prod.sh
# ============================================================
# SAFE. Does NOT delete volumes or images. Only:
#   - rebuilds changed images
#   - restarts services with zero data loss
#
# USAGE:
#   ./run-prod.sh              # up -d --build
#   ./run-prod.sh down         # stop all
#   ./run-prod.sh logs -f      # tail logs
#   ./run-prod.sh ps           # running containers
#   ./run-prod.sh restart      # restart stack
#   ./run-prod.sh pull         # pull latest images
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

[[ -f docker-compose.yml ]]      || { echo "❌ docker-compose.yml missing"; exit 1; }
[[ -f docker-compose.prod.yml ]] || { echo "❌ docker-compose.prod.yml missing"; exit 1; }
[[ -f .env.prod ]]               || { echo "❌ .env.prod missing"; exit 1; }

COMPOSE=(docker compose -f docker-compose.yml -f docker-compose.prod.yml --env-file .env.prod)

if [ $# -eq 0 ]; then
    echo "🚀 Building & starting production stack..."
    "${COMPOSE[@]}" up -d --build --remove-orphans
    echo "⏳ Waiting for backend health (max 240s)..."
    for i in $(seq 1 120); do
        if curl -sf http://localhost/api/v1/health >/dev/null 2>&1; then
            echo "✅ Backend healthy after $((i*2))s"
            echo ""
            echo "🌐 https://$(grep '^DOMAIN=' .env.prod | cut -d= -f2)"
            exit 0
        fi
        sleep 2
    done
    echo "❌ Health check failed. Showing last 100 logs:"
    "${COMPOSE[@]}" logs --tail=100 backend
    exit 1
fi

exec "${COMPOSE[@]}" "$@"