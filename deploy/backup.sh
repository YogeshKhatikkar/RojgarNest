#!/usr/bin/env bash
# ============================================================
# ROJGARNEST — BACKUP SCRIPT
# ============================================================
# Usage:
#   ./backup.sh
#
# Cron (daily at 2 AM):
#   0 2 * * * cd /opt/rojgarnest/deploy && ./backup.sh >> /var/log/rojgarnest-backup.log 2>&1
# ============================================================
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="/opt/rojgarnest/backups"
TS=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"

cd "$DEPLOY_DIR"

# Resolve actual container IDs (works regardless of COMPOSE_PROJECT_NAME)
MONGO_C=$(docker compose \
  -f docker-compose.yml -f docker-compose.prod.yml \
  --env-file .env.prod ps -q mongo 2>/dev/null || true)

REDIS_C=$(docker compose \
  -f docker-compose.yml -f docker-compose.prod.yml \
  --env-file .env.prod ps -q redis 2>/dev/null || true)

# ─── Mongo backup ───
if [ -n "$MONGO_C" ]; then
  echo "📦 Backing up MongoDB ($MONGO_C)..."
  docker exec "$MONGO_C" mongodump --db=RojgarNest --archive --gzip \
    > "$BACKUP_DIR/mongo_${TS}.archive.gz" 2>/dev/null || true
else
  echo "⚠️  MongoDB container not running — skipping"
fi

# ─── Redis backup ───
if [ -n "$REDIS_C" ]; then
  echo "📦 Backing up Redis ($REDIS_C)..."
  docker exec "$REDIS_C" redis-cli SAVE >/dev/null 2>&1 || true
  docker cp "$REDIS_C":/data/dump.rdb \
    "$BACKUP_DIR/redis_${TS}.rdb" 2>/dev/null || true
else
  echo "⚠️  Redis container not running — skipping"
fi

# ─── Retention: delete files older than 7 days ───
find "$BACKUP_DIR" -type f -mtime +7 -delete

echo "✅ Backup complete: $BACKUP_DIR"
ls -lh "$BACKUP_DIR" | tail -5