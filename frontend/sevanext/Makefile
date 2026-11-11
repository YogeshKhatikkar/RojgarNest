.PHONY: help local dev prod stop logs clean \
        build-web build-apk build-aab build-android \
        deploy deploy-prod rollback backup health test

help:
	@echo "🚀 RojgarNext — Available Commands"
	@echo "======================================================"
	@echo "  LOCAL:"
	@echo "    make local          → Start local dev (all services)"
	@echo "    make stop           → Stop all containers"
	@echo "    make logs           → Tail logs"
	@echo ""
	@echo "  BUILD:"
	@echo "    make build-web      → Build Flutter Web"
	@echo "    make build-apk      → Build universal APK"
	@echo "    make build-split    → Build per-ABI APKs"
	@echo "    make build-aab      → Build Play Store AAB"
	@echo "    make build-android  → All Android artifacts"
	@echo ""
	@echo "  DEPLOY:"
	@echo "    make deploy         → Deploy to staging"
	@echo "    make deploy-prod    → Deploy to production"
	@echo "    make rollback       → Rollback last deploy"
	@echo ""
	@echo "  OPS:"
	@echo "    make backup         → Backup Mongo + Redis"
	@echo "    make health         → Health check"
	@echo "    make test           → Run backend tests"
	@echo "    make clean          → Remove everything"
	@echo "======================================================"

# ============ LOCAL ============
local dev:
	bash deploy/scripts/deploy-local.sh

stop:
	cd deploy && docker compose -f docker-compose.dev.yml down

logs:
	cd deploy && docker compose -f docker-compose.dev.yml logs -f --tail=100

# ============ BUILD ============
build-web:
	bash deploy/scripts/build-web.sh

build-apk:
	bash deploy/scripts/build-android.sh apk

build-split:
	bash deploy/scripts/build-android.sh split

build-aab:
	bash deploy/scripts/build-android.sh aab

build-android:
	bash deploy/scripts/build-android.sh all

# ============ DEPLOY ============
deploy:
	bash deploy/scripts/deploy-server.sh staging

deploy-prod:
	bash deploy/scripts/deploy-server.sh production

rollback:
	cd deploy && docker compose -f docker-compose.prod.yml down
	cd deploy && docker compose -f docker-compose.prod.yml up -d --force-recreate

# ============ OPS ============
backup:
	bash deploy/scripts/backup.sh

health:
	@echo "🔍 Health:"
	@curl -sf http://localhost:8000/api/v1/health && echo " ✅ Backend" || echo " ❌ Backend"
	@curl -sf http://localhost:8080 >/dev/null && echo " ✅ Frontend" || echo " ❌ Frontend"

test:
	cd backend/rojgarnext && pytest -v

clean:
	cd deploy && docker compose -f docker-compose.dev.yml down -v --remove-orphans || true
	docker system prune -af || true