# ============================================================
# STAGE 1: Flutter Builder
# ============================================================
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# Cache deps
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

ARG API_BASE_URL=https://api.rojgarnest.com
ARG BUILD_NUMBER=1
ARG BUILD_NAME=2.0.0

RUN flutter build web --release \
    --base-href=/ \
    --web-renderer canvaskit \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=BUILD_NUMBER=${BUILD_NUMBER} \
    --dart-define=BUILD_NAME=${BUILD_NAME}

# ============================================================
# STAGE 2: Nginx Runtime
# ============================================================
FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -q --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]