#!/usr/bin/env bash
# ============================================================
# ROJGARNEST — DEVELOPMENT RUNNER (LOCAL COMPUTER ONLY)
# ============================================================
# Usage:
#   ./dev.sh              # start
#   ./dev.sh stop         # stop
#   ./dev.sh logs         # follow logs
#   ./dev.sh restart      # restart
#   ./dev.sh ps           # status
#   ./dev.sh rebuild      # full rebuild (no cache)
#   ./dev.sh clean        # stop + delete volumes (DESTROYS DATA)
#   ./dev.sh seed         # seed schemes
#   ./dev.sh shell        # shell into backend
#   ./dev.sh mongo        # shell into mongo
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
# GUARD — Prevent running on server
# ============================================================
if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${GITLAB_CI:-}" ]; then
    error "CI environment detected. Use ./prod.sh for server/production."
fi

# ============================================================
# COMPOSE COMMAND
# ============================================================
COMPOSE=(
    docker compose
    -f docker-compose.yml
    -f docker-compose.dev.yml
    --env-file .env.dev
)

# ============================================================
# ENSURE ENV FILE
# ============================================================
ensure_env() {
    if [ ! -f .env.dev ]; then
        if [ -f .env.dev.example ]; then
            cp .env.dev.example .env.dev
            warn "Created .env.dev from template"
        else
            error ".env.dev missing AND .env.dev.example missing"
        fi
    fi
}

# ============================================================
# COMMANDS
# ============================================================
cmd_start() {
    ensure_env
    log "Starting DEVELOPMENT stack (local)..."
    "${COMPOSE[@]}" up --build -d
    success "Development stack is up!"
    echo ""
    echo -e "  ${B}🌐 Frontend${N} : http://localhost:8080"
    echo -e "  ${B}🔌 Backend${N}  : http://localhost:8000"
    echo -e "  ${B}📚 API Docs${N} : http://localhost:8000/docs"
    echo -e "  ${B}🗄️  MongoDB${N}  : mongodb://localhost:27017"
    echo -e "  ${B}⚡ Redis${N}    : redis://localhost:6379"
    echo ""
    echo -e "  ${Y}Logs${N}: ./dev.sh logs"
    echo -e "  ${Y}Stop${N}: ./dev.sh stop"
    echo ""
}

cmd_stop() {
    log "Stopping DEVELOPMENT stack..."
    "${COMPOSE[@]}" down
    success "Stopped"
}

cmd_logs() {
    "${COMPOSE[@]}" logs -f
}

cmd_restart() {
    log "Restarting DEVELOPMENT stack..."
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
    warn "⚠️  This will DELETE ALL DATA (mongo + redis volumes)."
    warn "    Press Ctrl+C to cancel, Enter to continue."
    read -r
    "${COMPOSE[@]}" down -v --rmi local
    success "Cleaned — all data deleted"
}

cmd_seed() {
    log "Seeding schemes..."
    "${COMPOSE[@]}" exec backend python seed_schemes.py
    success "Seeding complete"
}

cmd_shell() {
    log "Opening shell in backend..."
    "${COMPOSE[@]}" exec backend bash
}

cmd_mongo() {
    log "Opening mongosh..."
    "${COMPOSE[@]}" exec mongo mongosh RojgarNest
}

cmd_health() {
    log "Checking health..."
    local ok=1
    curl -fsS http://localhost:8000/api/v1/health >/dev/null && echo -e "  ${G}✅${N} Backend  : OK" || { echo -e "  ${R}❌${N} Backend  : FAIL"; ok=0; }
    curl -fsS http://localhost:8080/healthz >/dev/null && echo -e "  ${G}✅${N} Frontend : OK" || { echo -e "  ${R}❌${N} Frontend : FAIL"; ok=0; }
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
    health)      cmd_health ;;
    *)
        echo "Usage: ./dev.sh <command>"
        echo ""
        echo "Commands:"
        echo "  start      Start development stack (default)"
        echo "  stop       Stop stack"
        echo "  logs       Follow logs"
        echo "  restart    Restart stack"
        echo "  ps         Show container status"
        echo "  rebuild    Full rebuild (no cache)"
        echo "  clean      Stop + delete volumes (DESTROYS DATA)"
        echo "  seed       Seed schemes"
        echo "  shell      Shell into backend"
        echo "  mongo      Shell into mongo"
        echo "  health     Check endpoints"
        exit 1
        ;;
esac