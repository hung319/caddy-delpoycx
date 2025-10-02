# Stage 1: Build Caddy với plugin cloudflare
FROM caddy:builder-alpine AS builder
RUN xcaddy build --with github.com/caddy-dns/cloudflare

# Stage 2: Final image
FROM alpine:3.20

# Cài dependencies
RUN apk add --no-cache supervisor python3 py3-pip curl git bash

# Copy Caddy đã build từ stage 1
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

# Cài cloudflared
RUN curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared

# Setup working dir
WORKDIR /app

# Clone webui + cài requirements
RUN git clone https://github.com/0xJacky/caddy-webui /webui && \
    pip3 install -r /webui/requirements.txt

# Copy file cấu hình
COPY app.py /webui/app.py
COPY Caddyfile /etc/caddy/Caddyfile
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80 443 5000

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
