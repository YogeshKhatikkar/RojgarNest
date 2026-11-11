#!/usr/bin/env bash
# ============================================================
# SevaNext - Local Docker Runner (Linux / macOS)
# File: deploy/run-local.sh
# ============================================================
# FULL NUKE + REBUILD for LOCAL development.
#   ./run-local.sh              # nuke all + rebuild + start
#   ./run-local.sh --no-nuke    # keep volumes, rebuild containers only
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

NO_NUKE=false
[[ "${1:-}" == "--no-nuke" ]] && NO_NUKE=true

C_CYAN='\033[0;36m'; C_YEL='\033[1;33m'; C_GRN='\033[0;32m'; C_RED='\033[0;31m'; C_NC='\033[0m'
hdr() { echo -e "\n${C_CYAN}================================================================${C_NC}"; echo -e "  $1"; echo -e "${C_CYAN}================================================================${C_NC}"; }
step() { echo -e "${C_YEL}[$(date +%H:%M:%S)] $1${C_NC}"; }
ok()   { echo -e "  ${C_GRN}✔ $1${C_NC}"; }
warn() { echo -e "  ${C_YEL}⚠ $1${C_NC}"; }
err()  { echo -e "  ${C_RED}✘ $1${C_NC}"; }

hdr "SEVANEXT - LOCAL DOCKER FULL RESET & DEPLOY"

[[ -f docker-compose.yml ]] || { err "docker-compose.yml missing"; exit 1; }
[[ -f .env.local ]]         || { err ".env.local missing"; exit 1; }
[[ -f ../backend/sevanext/.env ]] || warn "../backend/sevanext/.env missing"

COMPOSE=(docker compose -f docker-compose.yml -f docker-compose.dev.yml --env-file .env.local)

# ---- STEP 1: NUKE ----
if [ "$NO_NUKE" = false ]; then
    step "[1/8] FULL NUKE — removing containers, images, volumes, networks, build cache..."
    docker compose down -v --remove-orphans 2>/dev/null || true
    docker compose -f docker-compose.yml -f docker-compose.prod.yml --env-file .env.prod down -v --remove-orphans 2>/dev/null || true

    echo "  -> removing ALL containers"
    docker ps -aq | xargs -r docker rm -f 2>/dev/null || true

    echo "  -> removing ALL images"
    docker images -q | xargs -r docker rmi -f 2>/dev/null || true

    echo "  -> removing ALL volumes"
    docker volume ls -q | xargs -r docker volume rm -f 2>/dev/null || true

    echo "  -> pruning networks"
    docker network prune -f 2>/dev/null || true

    echo "  -> pruning build cache"
    docker builder prune -af 2>/dev/null || true

    echo "  -> pruning system"
    docker system prune -af --volumes 2>/dev/null || true

    ok "FULL NUKE complete."
else
    warn "[1/8] --no-nuke: keeping volumes & images"
    "${COMPOSE[@]}" down --remove-orphans 2>/dev/null || true
fi

# ---- STEP 2: DOCKER DAEMON ----
step "[2/8] Verifying Docker daemon..."
docker info >/dev/null 2>&1 || { err "Docker daemon not running."; exit 1; }
ok "Docker daemon running."

# ---- STEP 3: BUILD ----
step "[3/8] Building backend + frontend images..."
BUILD_ARGS=()
[ "$NO_NUKE" = false ] && BUILD_ARGS+=(--no-cache)
"${COMPOSE[@]}" build "${BUILD_ARGS[@]}" || { err "build FAILED — scroll up"; exit 1; }
ok "Images built."

# ---- STEP 4: START ----
step "[4/8] Starting stack..."
"${COMPOSE[@]}" up -d --remove-orphans || { err "up FAILED"; "${COMPOSE[@]}" logs --tail=80; exit 1; }
ok "Containers launched."

# ---- STEP 5: WAIT FOR MONGO ----
step "[5/8] Waiting for MongoDB (max 120s)..."
E=0; OK=false
while [ $E -lt 120 ]; do
    S=$(docker inspect --format='{{.State.Health.Status}}' sevanext-local-mongo 2>/dev/null || echo "starting")
    [ "$S" = "healthy" ] && { OK=true; break; }
    sleep 3; E=$((E+3)); echo "      [$E s] mongo: $S"
done
$OK || { err "MongoDB not healthy after 120s."; docker logs --tail 60 sevanext-local-mongo; exit 1; }
ok "MongoDB healthy."

# ---- STEP 6: WAIT FOR BACKEND ----
step "[6/8] Waiting for backend /api/v1/health (max 300s)..."
E=0; OK=false
while [ $E -lt 300 ]; do
    S=$(docker inspect --format='{{.State.Health.Status}}' sevanext-local-backend 2>/dev/null || echo "starting")
    if [ "$S" = "healthy" ]; then OK=true; break; fi
    if [ "$S" = "unhealthy" ]; then err "Backend UNHEALTHY"; docker logs --tail 100 sevanext-local-backend; exit 1; fi
    sleep 3; E=$((E+3)); echo "      [$E s] backend: $S"
done
if ! $OK; then
    warn "Backend not healthy after 300s — showing last 100 logs:"
    docker logs --tail 100 sevanext-local-backend || true
    warn "Common fixes: check ../backend/sevanext/.env has MONGO_URI, SECRET_KEY, JWT_SECRET_KEY"
fi

# ---- STEP 7: VERIFY PROXY CHAIN ----
step "[7/8] Verifying endpoints..."
curl -sf http://localhost:8000/api/v1/health >/dev/null && ok "Backend direct  : 200" || warn "Backend direct not reachable"
curl -sf http://localhost:8080/api/v1/health >/dev/null && ok "Nginx -> backend: 200" || warn "Nginx proxy not reachable"
curl -sf http://localhost:8080/            >/dev/null && ok "Frontend        : 200" || warn "Frontend not reachable"

# ---- STEP 8: SUCCESS ----
hdr "✅ DEPLOYMENT COMPLETE"
echo ""
echo "  🌐 Frontend:            http://localhost:8080"
echo "  📘 Swagger (direct):    http://localhost:8000/docs"
echo "  📘 Swagger (via nginx): http://localhost:8080/docs"
echo "  💚 Backend health:      http://localhost:8000/api/v1/health"
echo "  💚 Nginx health:        http://localhost:8080/api/v1/health"
echo "  🗄️  MongoDB:             mongodb://localhost:27017/SevaNext"
echo "  ⚡ Redis:                redis://localhost:6379"
echo ""
echo "  Commands:"
echo "    ${COMPOSE[*]} logs -f backend"
echo "    ${COMPOSE[*]} logs -f frontend"
echo "    ${COMPOSE[*]} ps"
echo "    ${COMPOSE[*]} down"
echo ""

# open browser (best-effort)
sleep 1
if command -v xdg-open >/dev/null; then xdg-open http://localhost:8080 >/dev/null 2>&1 || true
elif command -v open >/dev/null; then open http://localhost:8080 >/dev/null 2>&1 || true
fi

echo -e "${C_GRN}  🎉 Happy testing!${C_NC}"
echo ""