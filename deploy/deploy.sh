#!/usr/bin/env bash
# ============================================================
# ROJGARNEST — DEPLOYMENT HELPER
# ============================================================
set -euo pipefail

cd "$(dirname "$0")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# HELPERS
# ============================================================
log()      { echo -e "${CYAN}[deploy]${NC} $*"; }
success()  { echo -e "${GREEN}[ok]${NC} $*"; }
warn()     { echo -e "${YELLOW}[warn]${NC} $*"; }
error()    { echo -e "${RED}[error]${NC} $*" >&2; exit 1; }

# ============================================================
# COMMANDS
# ============================================================
cmd_dev_up() {
    log "Starting DEVELOPMENT stack..."
    docker compose \
        -f docker-compose.yml \
        -f docker-compose.dev.yml \
        --env-file .env.dev \
        up --build -d
    success "Development stack up. Frontend: http://localhost:8080 | Backend: http://localhost:8000"
}

cmd_dev_down() {
    log "Stopping DEVELOPMENT stack..."
    docker compose \
        -f docker-compose.yml \
        -f docker-compose.dev.yml \
        --env-file .env.dev \
        down
    success "Development stack down"
}

cmd_dev_logs() {
    docker compose \
        -f docker-compose.yml \
        -f docker-compose.dev.yml \
        --env-file .env.dev \
        logs -f
}

cmd_prod_up() {
    log "Starting PRODUCTION stack..."
    [ -f .env.prod ] || error ".env.prod not found — copy .env.prod.example"
    docker compose \
        -f docker-compose.yml \
        -f docker-compose.prod.yml \
        --env-file .env.prod \
        up --build -d
    success "Production stack up. Frontend: http://localhost | Backend: internal"
}

cmd_prod_down() {
    log "Stopping PRODUCTION stack..."
    docker compose \
        -f docker-compose.yml \
        -f docker-compose.prod.yml \
        --env-file .env.prod \
        down
    success "Production stack down"
}

cmd_prod_logs() {
    docker compose \
        -f docker-compose.yml \
        -f docker-compose.prod.yml \
        --env-file .env.prod \
        logs -f
}

cmd_backup_db() {
    log "Backing up MongoDB..."
    local ts=$(date +%Y%m%d_%H%M%S)
    local out="backups/mongo_${ts}.gz"
    mkdir -p backups
    docker compose exec -T mongo mongodump --archive --gzip > "$out"
    success "Backup saved: $out"
}

cmd_restore_db() {
    local file="${1:-}"
    [ -n "$file" ] || error "Usage: ./deploy.sh restore-db <backup.gz>"
    [ -f "$file" ] || error "File not found: $file"
    log "Restoring MongoDB from $file..."
    docker compose exec -T mongo mongorestore --archive --gzip < "$file"
    success "Restore complete"
}

cmd_seed() {
    log "Seeding schemes..."
    docker compose \
        -f docker-compose.yml \
        -f docker-compose.dev.yml \
        --env-file .env.dev \
        exec backend python seed_schemes.py
    success "Seeding complete"
}

cmd_status() {
    docker compose ps
}

cmd_health() {
    log "Checking health..."
    curl -fsS http://localhost:8000/api/v1/health && echo
    curl -fsS http://localhost:8080/healthz && echo
    success "All healthy"
}

# ============================================================
# ROUTER
# ============================================================
case "${1:-help}" in
    dev-up)      cmd_dev_up ;;
    dev-down)    cmd_dev_down ;;
    dev-logs)    cmd_dev_logs ;;
    prod-up)     cmd_prod_up ;;
    prod-down)   cmd_prod_down ;;
    prod-logs)   cmd_prod_logs ;;
    backup-db)   cmd_backup_db ;;
    restore-db)  shift; cmd_restore_db "${1:-}" ;;
    seed)        cmd_seed ;;
    status)      cmd_status ;;
    health)      cmd_health ;;
    *)
        cat <<EOF
Usage: ./deploy.sh <command>

DEV:
  dev-up       Start development stack
  dev-down     Stop development stack
  dev-logs     Follow development logs

PROD:
  prod-up      Start production stack
  prod-down    Stop production stack
  prod-logs    Follow production logs

DB:
  seed         Seed schemes into MongoDB
  backup-db    Backup MongoDB to deploy/backups/
  restore-db   Restore MongoDB from backup file

UTIL:
  status       Show container status
  health       Check endpoints
EOF
        ;;
esac