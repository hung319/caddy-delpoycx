# === STAGE 1: BUILDER ===
FROM golang:1.25-alpine AS builder

WORKDIR /app

RUN apk add --no-cache git bash
RUN go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
RUN xcaddy build v2.9.1 \
    --with github.com/gsmlg-dev/caddy-admin-ui@main

# === STAGE 2: FINAL IMAGE ===
FROM alpine:3.20

LABEL maintainer="Coder"
LABEL description="Caddy with Cloudflared, built with a custom Admin UI plugin."

ENV CLOUDFLARED_VERSION=2025.9.1
ENV CLOUDFLARE_TOKEN=""
ENV CADDY_ADMIN_USER="admin"
ENV CADDY_ADMIN_PASSWORD=""

RUN apk add --no-cache \
    supervisor \
    bash \
    curl \
    ca-certificates

ARG TARGETARCH
RUN ARCH=${TARGETARCH:-amd64} && \
    curl -L --output cloudflared "https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-${ARCH}" && \
    chmod +x cloudflared && \
    mv cloudflared /usr/local/bin/cloudflared

COPY --from=builder /app/caddy /usr/sbin/caddy

# TẠO THƯ MỤC CẤU HÌNH CHO CADDY
RUN mkdir -p /etc/caddy

# Copy các file cấu hình
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
