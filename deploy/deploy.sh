#!/usr/bin/env bash
# ============================================================
# ONE-CLICK VPS DEPLOY SCRIPT
# Works on: Ubuntu 20.04/22.04/24.04, Debian 11/12
# ============================================================
set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $*"; }
ok()  { echo -e "${GREEN}✅ $*${NC}"; }
fail(){ echo -e "${RED}❌ $*${NC}"; exit 1; }
warn(){ echo -e "${YELLOW}⚠️  $*${NC}"; }

APP_DIR="${APP_DIR:-/opt/rojgarnext}"
REPO_URL="${REPO_URL:-}"
BRANCH="${BRANCH:-main}"
DOMAIN="${DOMAIN:-www.rojgarnest.com}"
EMAIL="${EMAIL:-admin@rojgarnest.com}"

# 1. Check requirements
if [ "$EUID" -eq 0 ]; then
  fail "Do NOT run this script as root. Use a regular sudo user."
fi

# 2. Install Docker
if ! command -v docker &>/dev/null; then
  log "Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
  ok "Docker installed. You may need to log out and back in."
fi

if ! docker compose version &>/dev/null; then
  log "Installing Docker Compose plugin..."
  sudo apt-get update
  sudo apt-get install -y docker-compose-plugin
  ok "Docker Compose installed"
fi

# 3. Clone or pull repo
if [ ! -d "$APP_DIR" ]; then
  if [ -z "$REPO_URL" ]; then
    fail "APP_DIR does not exist and REPO_URL not set. Set REPO_URL=https://github.com/your/repo.git"
  fi
  log "Cloning repo to $APP_DIR..."
  sudo mkdir -p "$APP_DIR"
  sudo chown "$USER:$USER" "$APP_DIR"
  git clone --branch "$BRANCH" "$REPO_URL" "$APP_DIR"
else
  log "Pulling latest changes..."
  cd "$APP_DIR"
  git fetch origin
  git reset --hard "origin/$BRANCH"
fi

cd "$APP_DIR"

# 4. Check .env
ENV_FILE="$APP_DIR/backend/rojgarnext/.env"
if [ ! -f "$ENV_FILE" ]; then
  warn ".env not found. Copying from .env.example..."
  if [ -f "$APP_DIR/backend/rojgarnext/.env.example" ]; then
    cp "$APP_DIR/backend/rojgarnext/.env.example" "$ENV_FILE"
    warn "⚠️  EDIT $ENV_FILE with real values before continuing!"
    exit 0
  else
    fail ".env and .env.example both missing. Cannot continue."
  fi
fi

# 5. Create required directories
mkdir -p backend/rojgarnext/{uploads,secure,models,logs,backups}

# 6. SSL certificates
if [ ! -d "deploy/certbot/conf/live/$DOMAIN" ]; then
  log "Setting up SSL certificates for $DOMAIN..."
  mkdir -p deploy/certbot/conf deploy/certbot/www

  docker run -d --name temp-nginx \
    -p 80:80 \
    -v "$(pwd)/deploy/certbot/www:/var/www/certbot:ro" \
    nginx:alpine || true
  sleep 3

  docker run --rm \
    -v "$(pwd)/deploy/certbot/conf:/etc/letsencrypt" \
    -v "$(pwd)/deploy/certbot/www:/var/www/certbot" \
    certbot/certbot certonly --webroot \
    -w /var/www/certbot \
    --email "$EMAIL" \
    --agree-tos --no-eff-email \
    -d "$DOMAIN" -d "${DOMAIN#www.}" || warn "Certbot failed — continuing without SSL"

  docker stop temp-nginx 2>/dev/null || true
  docker rm temp-nginx 2>/dev/null || true
fi

# 7. Build & deploy
log "Building Docker images (5-10 min)..."
cd deploy

export GITHUB_REPOSITORY_OWNER="${GITHUB_REPOSITORY_OWNER:-your-org}"
export IMAGE_TAG="${IMAGE_TAG:-latest}"

docker compose -f docker-compose.prod.yml build --parallel

log "Starting services..."
docker compose -f docker-compose.prod.yml up -d --remove-orphans

# 8. Health check
log "Waiting for services to become healthy..."
for i in $(seq 1 60); do
  if curl -sf http://localhost/api/v1/health >/dev/null 2>&1; then
    ok "Backend healthy after ${i}s"
    break
  fi
  if [ "$i" -eq 60 ]; then
    fail "Health check failed after 120s. Check: docker compose logs backend"
  fi
  sleep 2
done

# 9. Cleanup
docker image prune -f >/dev/null 2>&1 || true
docker builder prune -f --filter "until=72h" >/dev/null 2>&1 || true

# 10. Summary
echo ""
echo "============================================================"
ok "🎉 DEPLOYMENT SUCCESSFUL"
echo "============================================================"
echo "   🌐 Web App:     https://$DOMAIN"
echo "   📚 API Docs:    https://$DOMAIN/docs"
echo ""
echo "   Logs:   cd $APP_DIR/deploy && docker compose -f docker-compose.prod.yml logs -f"
echo "   Stop:   cd $APP_DIR/deploy && docker compose -f docker-compose.prod.yml down"
echo "   Status: cd $APP_DIR/deploy && docker compose -f docker-compose.prod.yml ps"
echo "============================================================"