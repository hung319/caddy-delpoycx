FROM caddy:2-builder AS builder
RUN xcaddy build --with github.com/caddy-dns/cloudflare

FROM caddy:2
RUN apt-get update && apt-get install -y supervisor python3 python3-pip curl git
RUN curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared

WORKDIR /app
RUN git clone https://github.com/0xJacky/caddy-webui /webui && \
    pip3 install -r /webui/requirements.txt

# Copy file app.py đã chỉnh auth
COPY app.py /webui/app.py
COPY Caddyfile /etc/caddy/Caddyfile
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80 443 5000
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]