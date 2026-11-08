# ============================================================
# ROJGARNEST FRONTEND DOCKERFILE — PRODUCTION READY
# Flutter web build + Nginx serve
# ============================================================

# ------------------------------------------------------------
# STAGE 1: Flutter Builder
# ------------------------------------------------------------
# ✅ Pinned version for reproducibility
FROM ghcr.io/cirruslabs/flutter:3.24.5 AS builder

WORKDIR /app

# ✅ Copy pubspec files first (better layer caching)
COPY pubspec.yaml ./
COPY pubspec.lock ./

RUN flutter pub get

# Copy source code
COPY . .

# Build web app
ARG API_BASE_URL=https://www.rojgarnest.com/api/v1
ARG WS_BASE_URL=wss://www.rojgarnest.com/notification/ws
ARG BUILD_NUMBER=1
ARG BUILD_NAME=2.0.0

RUN flutter build web --release \
    --base-href=/ \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=WS_BASE_URL=${WS_BASE_URL} \
    --dart-define=BUILD_NUMBER=${BUILD_NUMBER} \
    --dart-define=BUILD_NAME=${BUILD_NAME}

# ------------------------------------------------------------
# STAGE 2: Nginx Runtime
# ------------------------------------------------------------
FROM nginx:1.27-alpine

# Remove default nginx conf
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx conf
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built Flutter web app
COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD wget -q --spider http://localhost/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]