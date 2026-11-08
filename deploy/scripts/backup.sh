#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/opt/rojgarnest/backups"
TS=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"

# Mongo
docker exec rojgarnest_mongo mongodump --db=RojgarNest --archive --gzip > \
  "$BACKUP_DIR/mongo_${TS}.archive.gz" 2>/dev/null || true

# Redis
docker exec rojgarnest_redis redis-cli SAVE >/dev/null 2>&1 || true
docker cp rojgarnest_redis:/data/dump.rdb \
  "$BACKUP_DIR/redis_${TS}.rdb" 2>/dev/null || true

# Retention 7 days
find "$BACKUP_DIR" -type f -mtime +7 -delete

echo "✅ Backup: $BACKUP_DIR"