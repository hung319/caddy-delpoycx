# === STAGE 1: BUILDER ===
FROM golang:1.25-alpine AS builder
WORKDIR /app
RUN apk add --no-cache git bash
RUN go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

# SỬA ĐỔI Ở ĐÂY: Build Caddy gốc mà không cần thêm plugin Web UI bên ngoài
RUN xcaddy build v2.9.1

# === STAGE 2: FINAL IMAGE ===
FROM alpine:3.20

# Cài đặt Python và các thư viện bằng APK
RUN apk add --no-cache \
    supervisor \
    bash \
    curl \
    ca-certificates \
    python3 \
    py3-pip \
    py3-flask \
    py3-requests

# Cài đặt cloudflared
ENV CLOUDFLARED_VERSION=2024.9.1
ARG TARGETARCH
RUN ARCH=${TARGETARCH:-amd64} && \
    curl -L --output cloudflared "https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-${ARCH}" && \
    chmod +x cloudflared && \
    mv cloudflared /usr/local/bin/cloudflared

# Copy Caddy đã build và tạo thư mục config
COPY --from=builder /app/caddy /usr/sbin/caddy
RUN mkdir -p /etc/caddy

# Copy backend và frontend
COPY backend/app.py /app/backend/app.py
COPY frontend/ /app/frontend/

# Copy các file cấu hình
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Khai báo các biến môi trường
ENV CLOUDFLARE_TOKEN=""
ENV CADDY_ADMIN_USER="admin"
ENV CADDY_ADMIN_PASSWORD=""

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
