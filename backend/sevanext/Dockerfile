# ============================================================
# SEVANEXT BACKEND DOCKERFILE — PRODUCTION READY
# ============================================================
# Multi-stage build, non-root user, works for dev + prod.
#
# Highlights:
#   - Builder stage: gcc/g++ for compiled Python deps (pymongo C ext, cryptography, etc.)
#   - Runtime stage: slim, non-root `appuser`, curl for healthcheck
#   - tini as init (proper signal handling / zombie reaping)
#   - uvicorn with configurable workers ($WORKERS env var)
#   - --proxy-headers + --forwarded-allow-ips for nginx upstream
#   - HEALTHCHECK against /api/v1/health
#
# ENV OVERRIDES (from docker-compose):
#   WORKERS              default 1 (dev) / 4 (prod)
#   FORWARDED_ALLOW_IPS  default "*"
#   PORT                 default 8000
# ============================================================

# ------------------------------------------------------------
# STAGE 1: Builder
# ------------------------------------------------------------
FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_DEFAULT_TIMEOUT=120 \
    PIP_RETRIES=10

WORKDIR /app

# Build toolchain for compiled wheels (pymongo, cryptography, bcrypt, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc \
        g++ \
        build-essential \
        libffi-dev \
        libssl-dev \
        libxml2-dev \
        libxslt1-dev \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Isolated venv — copied wholesale to runtime stage
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python deps first (layer caching)
COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt


# ------------------------------------------------------------
# STAGE 2: Runtime
# ------------------------------------------------------------
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=utf-8 \
    PYTHONUTF8=1 \
    PATH="/opt/venv/bin:$PATH" \
    PORT=8000 \
    WORKERS=1 \
    FORWARDED_ALLOW_IPS="*"

# Non-root user
RUN groupadd -r appuser && useradd -r -g appuser -m -d /home/appuser appuser

# Runtime system deps (tini = init, curl = healthcheck)
RUN apt-get update && apt-get install -y --no-install-recommends \
        tini \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the ready-made venv from builder (no compiler in runtime)
COPY --from=builder /opt/venv /opt/venv

# Copy app code, owned by appuser
COPY --chown=appuser:appuser . .

# Runtime writable dirs (must be created BEFORE USER switch)
RUN mkdir -p uploads secure models logs backups && \
    chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

# Healthcheck (backend must expose /api/v1/health)
HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=5 \
    CMD curl -fsS "http://localhost:${PORT}/api/v1/health" || exit 1

# ✅ tini as PID 1 (proper signal handling + zombie reaping)
# ✅ uvicorn with configurable workers, proxy headers, keep-alive for nginx
ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["sh", "-c", "exec uvicorn app.main:app \
    --host 0.0.0.0 \
    --port ${PORT} \
    --workers ${WORKERS} \
    --proxy-headers \
    --forwarded-allow-ips \"${FORWARDED_ALLOW_IPS}\" \
    --timeout-keep-alive 5 \
    --access-log"]