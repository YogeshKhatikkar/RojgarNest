# ============================================================
# ROJGARNEST BACKEND DOCKERFILE — PRODUCTION READY
# Multi-stage build, non-root user, works for dev + prod
# ============================================================

# ------------------------------------------------------------
# STAGE 1: Builder
# ------------------------------------------------------------
FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Build dependencies (needed to compile some packages)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    build-essential \
    libffi-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Virtual environment inside image
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python dependencies first (better layer caching)
COPY requirements.txt .
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
    PATH="/opt/venv/bin:$PATH"

# Non-root user
RUN groupadd -r appuser && useradd -r -g appuser -m appuser

# Runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Copy application code
COPY --chown=appuser:appuser . .

# Create writable directories
RUN mkdir -p uploads secure models logs backups && \
    chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=5 \
    CMD curl -fsS http://localhost:8000/api/v1/health || exit 1

# ✅ FIXED: Single-worker uvicorn (prevents scheduler duplication)
# ✅ Uses --proxy-headers for correct IP detection behind Nginx
CMD ["uvicorn", "app.main:app", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--workers", "1", \
     "--proxy-headers", \
     "--forwarded-allow-ips", "*", \
     "--timeout-keep-alive", "5", \
     "--access-log"]