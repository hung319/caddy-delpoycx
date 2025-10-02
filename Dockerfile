# === STAGE 1: BUILDER ===
FROM golang:1.25-alpine AS builder

# THÊM DÒNG NÀY: Thiết lập thư mục làm việc rõ ràng
WORKDIR /app

# Cài đặt các công cụ cần thiết cho build
RUN apk add --no-cache git bash

# Cài đặt xcaddy
RUN go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

# Build Caddy với plugin admin UI. File 'caddy' sẽ được tạo trong /app
RUN xcaddy build v2.9.1 \
    --with github.com/gsmlg-dev/caddy-admin-ui@main

# === STAGE 2: FINAL IMAGE ===
FROM alpine:3.20

# Metadata cho image
LABEL maintainer="Coder"
LABEL description="Caddy with Cloudflared, built with a custom Admin UI plugin."

ENV CLOUDFLARED_VERSION=2024.9.1

# Các biến môi trường cho runtime
ENV CLOUDFLARE_TOKEN=""
ENV CADDY_ADMIN_USER="admin"
ENV CADDY_ADMIN_PASSWORD=""

# Cài đặt các dependencies cần thiết để chạy
RUN apk add --no-cache \
    supervisor \
    bash \
    curl \
    ca-certificates

# Cài đặt cloudflared
ARG TARGETARCH
RUN ARCH=${TARGETARCH:-amd64} && \
    curl -L --output cloudflared "https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-${ARCH}" && \
    chmod +x cloudflared && \
    mv cloudflared /usr/local/bin/cloudflared

# SỬA ĐỔI Ở ĐÂY: Copy file Caddy từ đúng đường dẫn trong stage builder
COPY --from=builder /app/caddy /usr/sbin/caddy

# Copy các file cấu hình
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
