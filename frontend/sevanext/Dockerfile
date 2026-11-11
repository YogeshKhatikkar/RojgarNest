# ============================================================
# SevaNext FRONTEND DOCKERFILE
# ============================================================
# Flutter 3.38.2 includes Dart 3.10.0, required by go_router >= 17.3.0
# ============================================================

FROM ghcr.io/cirruslabs/flutter:3.38.2 AS builder

WORKDIR /app

# Copy dependency manifests first for better layer caching
COPY pubspec.yaml ./
COPY pubspec.lock ./

# Resolve dependencies (now compatible with Dart 3.10.0)
RUN flutter pub get

# Copy the rest of the project
COPY . .

# Build arguments — LOCAL dev defaults (overridable via compose)
ARG API_BASE_URL=http://localhost:8000/api/v1
ARG WS_BASE_URL=ws://localhost:8000/notification/ws
ARG BUILD_NUMBER=1
ARG BUILD_NAME=2.0.0

# Build Flutter web in release mode
RUN flutter build web --release \
    --base-href=/ \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=WS_BASE_URL=${WS_BASE_URL} \
    --dart-define=BUILD_NUMBER=${BUILD_NUMBER} \
    --dart-define=BUILD_NAME=${BUILD_NAME}

# ============================================================
# Runtime stage — Nginx
# ============================================================
FROM nginx:1.27-alpine

RUN rm /etc/nginx/conf.d/default.conf

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80

# ✅ FIXED: was "ngiretries" — now "retries"
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD wget -q --spider http://localhost/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]