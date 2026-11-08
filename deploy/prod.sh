#!/usr/bin/env bash
# ============================================================
# ROJGARNEST — PRODUCTION RUNNER (SERVER ONLY)
# ============================================================
# Usage:
#   ./prod.sh              # start
#   ./prod.sh stop         # stop
#   ./prod.sh logs         # follow logs
#   ./prod.sh restart      # restart
#   ./prod.sh ps           # status
#   ./prod.sh rebuild      # full rebuild (no cache)
#   ./prod.sh clean        # stop + delete volumes (DESTROYS DATA)
#   ./prod.sh seed         # seed schemes
#   ./prod.sh shell        # shell into backend
#   ./prod.sh mongo        # shell into mongo
#   ./prod.sh backup       # backup mongo to deploy/backups/
#   ./prod.sh restore F    # restore mongo from file F
#   ./prod.sh health       # check endpoints
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

# Colors
G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; C='\033[0;36m'; B='\033[1m'; N='\033[0m'
log()     { echo -e "${C}▶${N} $*"; }
success() { echo -e "${G}✅${N} $*"; }
warn()    { echo -e "${Y}⚠️${N}  $*"; }
error()   { echo -e "${R}❌${N} $*" >&2; exit 1; }

# ============================================================
# COMPOSE COMMAND
# ============================================================
COMPOSE=(
    docker compose
    -f docker-compose.yml
    -f docker-compose.prod.yml
    --env-file .env.prod
)

# ============================================================
# ENSURE ENV FILE
# ============================================================
ensure_env() {
    if [ ! -f .env.prod ]; then
        error ".env.prod not found. Copy from .env.prod.example and fill MONGO_ROOT_PASSWORD."
    fi

    # Validate required vars
    if ! grep -q "^MONGO_ROOT_PASSWORD=.\+" .env.prod; then
        error "MONGO_ROOT_PASSWORD not set in .env.prod"
    fi
    if ! grep -q "^MONGO_ROOT_USERNAME=.\+" .env.prod; then
        error "MONGO_ROOT_USERNAME not set in .env.prod"
    fi
}

# ============================================================
# COMMANDS
# ============================================================
cmd_start() {
    ensure_env
    log "Starting PRODUCTION stack (server)..."
    "${COMPOSE[@]}" up --build -d
    success "Production stack is up!"
    echo ""
    local ip
    ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
    echo -e "  ${B}🌐 Frontend${N} : http://${ip}:80"
    echo -e "  ${B}🔌 Backend${N}  : internal (via Nginx reverse proxy)"
    echo ""
    echo -e "  ${Y}Logs${N}: ./prod.sh logs"
    echo -e "  ${Y}Stop${N}: ./prod.sh stop"
    echo ""
}

cmd_stop() {
    log "Stopping PRODUCTION stack..."
    "${COMPOSE[@]}" down
    success "Stopped"
}

cmd_logs() {
    "${COMPOSE[@]}" logs -f
}

cmd_restart() {
    log "Restarting PRODUCTION stack..."
    "${COMPOSE[@]}" restart
    success "Restarted"
}

cmd_ps() {
    "${COMPOSE[@]}" ps
}

cmd_rebuild() {
    ensure_env
    log "Full rebuild (no cache) — this takes 8-12 minutes..."
    "${COMPOSE[@]}" down
    "${COMPOSE[@]}" build --no-cache
    "${COMPOSE[@]}" up -d
    success "Rebuild complete"
}

cmd_clean() {
    warn "⚠️  This will DELETE ALL PRODUCTION DATA."
    warn "    Type 'DELETE' to confirm:"
    read -r confirm
    [ "$confirm" = "DELETE" ] || { warn "Cancelled"; exit 0; }
    "${COMPOSE[@]}" down -v --rmi local
    success "Cleaned — all data deleted"
}

cmd_seed() {
    log "Seeding schemes (production)..."
    "${COMPOSE[@]}" exec backend python seed_schemes.py
    success "Seeding complete"
}

cmd_shell() {
    log "Opening shell in backend..."
    "${COMPOSE[@]}" exec backend bash
}

cmd_mongo() {
    log "Opening mongosh (with auth)..."
    local user pass
    user=$(grep "^MONGO_ROOT_USERNAME=" .env.prod | cut -d= -f2)
    pass=$(grep "^MONGO_ROOT_PASSWORD=" .env.prod | cut -d= -f2)
    "${COMPOSE[@]}" exec mongo mongosh -u "$user" -p "$pass" --authenticationDatabase admin RojgarNest
}

cmd_backup() {
    ensure_env
    log "Backing up MongoDB..."
    mkdir -p backups
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local file="backups/mongo_${ts}.gz"
    "${COMPOSE[@]}" exec -T mongo sh -c \
        'mongodump --archive --gzip --uri="mongodb://$(MONGO_ROOT_USERNAME):$(MONGO_ROOT_PASSWORD)@localhost:27017/RojgarNest?authSource=admin"' \
        > "$file"
    success "Backup saved: $file ($(du -h "$file" | cut -f1))"
}

cmd_restore() {
    ensure_env
    local file="${1:-}"
    [ -n "$file" ] || error "Usage: ./prod.sh restore <backup.gz>"
    [ -f "$file" ] || error "File not found: $file"
    warn "⚠️  This will overwrite current data. Type 'RESTORE' to confirm:"
    read -r confirm
    [ "$confirm" = "RESTORE" ] || { warn "Cancelled"; exit 0; }
    log "Restoring MongoDB from $file..."
    "${COMPOSE[@]}" exec -T mongo sh -c \
        'mongorestore --archive --gzip --uri="mongodb://$(MONGO_ROOT_USERNAME):$(MONGO_ROOT_PASSWORD)@localhost:27017/RojgarNest?authSource=admin"' \
        < "$file"
    success "Restore complete"
}

cmd_health() {
    log "Checking health..."
    local ok=1
    local ip
    ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
    curl -fsS "http://${ip}/healthz" >/dev/null && echo -e "  ${G}✅${N} Frontend : OK" || { echo -e "  ${R}❌${N} Frontend : FAIL"; ok=0; }
    curl -fsS "http://${ip}/api/v1/health" >/dev/null && echo -e "  ${G}✅${N} Backend  : OK" || { echo -e "  ${R}❌${N} Backend  : FAIL"; ok=0; }
    [ $ok -eq 1 ] && success "All healthy" || error "Some services unhealthy"
}

# ============================================================
# ROUTER
# ============================================================
case "${1:-start}" in
    start|up)    cmd_start ;;
    stop|down)   cmd_stop ;;
    logs)        cmd_logs ;;
    restart)     cmd_restart ;;
    ps|status)   cmd_ps ;;
    rebuild)     cmd_rebuild ;;
    clean)       cmd_clean ;;
    seed)        cmd_seed ;;
    shell)       cmd_shell ;;
    mongo)       cmd_mongo ;;
    backup)      cmd_backup ;;
    restore)     shift; cmd_restore "${1:-}" ;;
    health)      cmd_health ;;
    *)
        echo "Usage: ./prod.sh <command>"
        echo ""
        echo "Commands:"
        echo "  start          Start production stack (default)"
        echo "  stop           Stop stack"
        echo "  logs           Follow logs"
        echo "  restart        Restart stack"
        echo "  ps             Show container status"
        echo "  rebuild        Full rebuild (no cache)"
        echo "  clean          Stop + delete volumes (DESTROYS DATA)"
        echo "  seed           Seed schemes"
        echo "  shell          Shell into backend"
        echo "  mongo          Shell into mongo (with auth)"
        echo "  backup         Backup mongo to deploy/backups/"
        echo "  restore <file> Restore mongo from backup file"
        echo "  health         Check endpoints"
        exit 1
        ;;
esac