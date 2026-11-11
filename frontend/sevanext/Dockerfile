# ============================================================
# SevaNext FRONTEND DOCKERFILE
# ============================================================
# Flutter 3.38.2 includes Dart 3.10.0, required by go_router >= 17.3.0
# ============================================================
# WHAT THIS FILE DOES:
#   1. Builds Flutter web in release mode
#   2. Copies build/web into an nginx image
#   3. nginx serves static files + proxies /api/v1 → backend:8000
#
# IMPORTANT BUILD ARGS:
#   API_BASE_URL  MUST be a RELATIVE path like "/api/v1"
#                 (nginx in the same container proxies to backend)
#                 NOT "http://localhost:8000/..." — that fails on prod.
#   WS_BASE_URL   MUST be a RELATIVE path like "/notification/ws"
# ============================================================

FROM ghcr.io/cirruslabs/flutter:3.38.2 AS builder

WORKDIR /app

# ---- Dependency manifests first (layer caching) ----
COPY pubspec.yaml ./
COPY pubspec.lock ./

# ---- Resolve dependencies ----
RUN flutter pub get

# ---- Copy the rest of the project ----
COPY . .

# ============================================================
# Build-time arguments
# ============================================================
# ✅ DEFAULT = RELATIVE PATH (safe for BOTH local docker and prod)
#    Override via docker-compose build.args if needed.
# ============================================================
ARG API_BASE_URL=/api/v1
ARG WS_BASE_URL=/notification/ws
ARG BUILD_NUMBER=1
ARG BUILD_NAME=2.0.0

# ---- Build Flutter web in release mode ----
RUN flutter build web --release \
    --base-href=/ \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=WS_BASE_URL=${WS_BASE_URL} \
    --dart-define=BUILD_NUMBER=${BUILD_NUMBER} \
    --dart-define=BUILD_NAME=${BUILD_NAME}

# ============================================================
# Runtime stage — nginx
# ============================================================
FROM nginx:1.27-alpine

# Remove default config, use our custom one
RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy Flutter web build
COPY --from=builder /app/build/web /usr/share/nginx/html

# nginx runs as root by default in this image (needed for port 80)
EXPOSE 80

# ✅ Healthcheck — must match `location = /healthz` in nginx.conf
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD wget -q --spider http://localhost/healthz || exit 1

# ✅ Graceful shutdown for Docker stop
STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]