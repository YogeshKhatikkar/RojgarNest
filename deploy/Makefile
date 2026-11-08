# ============================================================
# ROJGARNEST — MAKEFILE
# ============================================================
.PHONY: help dev-up dev-down dev-logs prod-up prod-down prod-logs seed backup-db status health

# ============================================================
# VARIABLES
# ============================================================
COMPOSE_DEV = docker compose -f docker-compose.yml -f docker-compose.dev.yml --env-file .env.dev
COMPOSE_PROD = docker compose -f docker-compose.yml -f docker-compose.prod.yml --env-file .env.prod

# ============================================================
# HELP
# ============================================================
help:
	@echo "RojgarNest Deployment Commands:"
	@echo ""
	@echo "  make dev-up      Start development stack"
	@echo "  make dev-down    Stop development stack"
	@echo "  make dev-logs    Follow development logs"
	@echo "  make prod-up     Start production stack"
	@echo "  make prod-down   Stop production stack"
	@echo "  make prod-logs   Follow production logs"
	@echo "  make seed        Seed schemes"
	@echo "  make backup-db   Backup MongoDB"
	@echo "  make status      Container status"
	@echo "  make health      Check endpoints"

# ============================================================
# DEV
# ============================================================
dev-up:
	$(COMPOSE_DEV) up --build -d

dev-down:
	$(COMPOSE_DEV) down

dev-logs:
	$(COMPOSE_DEV) logs -f

# ============================================================
# PROD
# ============================================================
prod-up:
	$(COMPOSE_PROD) up --build -d

prod-down:
	$(COMPOSE_PROD) down

prod-logs:
	$(COMPOSE_PROD) logs -f

# ============================================================
# UTILS
# ============================================================
seed:
	$(COMPOSE_DEV) exec backend python seed_schemes.py

backup-db:
	mkdir -p backups
	docker compose exec -T mongo mongodump --archive --gzip > backups/mongo_$$(date +%Y%m%d_%H%M%S).gz

status:
	docker compose ps

health:
	curl -fsS http://localhost:8000/api/v1/health && echo
	curl -fsS http://localhost:8080/healthz && echo