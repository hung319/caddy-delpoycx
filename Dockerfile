# Sử dụng base image Alpine Linux mới nhất để giữ cho image nhỏ gọn
FROM alpine:latest

# Metadata cho image
LABEL maintainer="Coder"
LABEL description="Caddy with Cloudflared tunnel and a web UI, configured via environment variables."

# Khai báo các biến môi trường cho phiên bản để dễ dàng cập nhật
ENV CADDY_VERSION=2.8.4
ENV CLOUDFLARED_VERSION=2024.9.1
ENV CADDY_UI_VERSION=1.3.1

# Khai báo các biến môi trường mà người dùng sẽ cung cấp lúc chạy container
ENV CLOUDFLARE_TOKEN=""
ENV CADDY_ADMIN_USER="admin"
ENV CADDY_ADMIN_PASSWORD=""
ENV CADDY_DOMAIN="localhost"

# Build-time argument để build image cho nhiều kiến trúc CPU (amd64, arm64)
ARG TARGETARCH

# Cài đặt các package cần thiết và dọn dẹp cache
RUN apk update && apk add --no-cache \
    caddy=${CADDY_VERSION}-r0 \
    supervisor \
    bash \
    curl \
    # Thêm repo của Caddy
    && echo "http://dl-cdn.alpinelinux.org/alpine/v3.18/community" >> /etc/apk/repositories

# Cài đặt cloudflared
RUN ARCH=${TARGETARCH:-amd64} && \
    curl -L --output cloudflared "https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-${ARCH}" && \
    chmod +x cloudflared && \
    mv cloudflared /usr/local/bin/cloudflared

# Tải và cài đặt Caddy Admin UI (giao diện web để quản lý Caddy)
RUN mkdir -p /var/www/html/caddy-ui && \
    curl -L https://github.com/caddyserver/admin-ui/releases/download/v${CADDY_UI_VERSION}/caddy-admin-ui.tar.gz -o /tmp/caddy-ui.tar.gz && \
    tar -xzf /tmp/caddy-ui.tar.gz -C /var/www/html/caddy-ui && \
    rm /tmp/caddy-ui.tar.gz

# Copy file cấu hình của Supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy và cấp quyền thực thi cho entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Port mà Caddy sẽ lắng nghe bên trong container
EXPOSE 80

# Chạy entrypoint script khi container khởi động
ENTRYPOINT ["/entrypoint.sh"]