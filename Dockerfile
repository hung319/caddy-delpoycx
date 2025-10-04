# === STAGE 1: BUILDER (Không đổi) ===
FROM golang:1.25-alpine AS builder
WORKDIR /app
RUN apk add --no-cache git bash
RUN go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
RUN xcaddy build v2.9.1

# === STAGE 2: FINAL IMAGE ===
FROM alpine:3.20

RUN apk add --no-cache \
    supervisor \
    bash \
    curl \
    ca-certificates \
    python3 \
    py3-pip \
    py3-flask \
    py3-requests \
    py3-boto3

# ... (Phần cài đặt cloudflared không đổi) ...
ENV CLOUDFLARED_VERSION=2025.9.1
ARG TARGETARCH
RUN ARCH=${TARGETARCH:-amd64} && \
    curl -L --output cloudflared "https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-${ARCH}" && \
    chmod +x cloudflared && \
    mv cloudflared /usr/local/bin/cloudflared

# ... (Phần copy Caddy, backend, frontend không đổi) ...
COPY --from=builder /app/caddy /usr/sbin/caddy
RUN mkdir -p /etc/caddy
COPY backend/app.py /app/backend/app.py
COPY frontend/ /app/frontend/
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Khai báo các biến môi trường
ENV CLOUDFLARE_TOKEN=""
ENV CADDY_ADMIN_USER="admin"
ENV CADDY_ADMIN_PASSWORD=""
# THAY ĐỔI BIẾN MÔI TRƯỜNG CHO S3 TƯƠNG THÍCH
ENV S3_BUCKET_NAME=""
ENV S3_ENDPOINT_URL=""
ENV AWS_ACCESS_KEY_ID=""
ENV AWS_SECRET_ACCESS_KEY=""
ENV S3_BACKUP_FILENAME="Caddyfile.bak"

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
