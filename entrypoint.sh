#!/bin/bash
set -e

# ... (phần kiểm tra biến môi trường và hash password giữ nguyên) ...
if [ -z "$CLOUDFLARE_TOKEN" ]; then echo "Lỗi: CLOUDFLARE_TOKEN chưa được thiết lập." >&2; exit 1; fi
if [ -z "$CADDY_ADMIN_PASSWORD" ]; then echo "Lỗi: CADDY_ADMIN_PASSWORD chưa được thiết lập." >&2; exit 1; fi
HASHED_PASSWORD=$(caddy hash-password --plaintext "$CADDY_ADMIN_PASSWORD")

# Tạo file Caddyfile
cat <<EOF > /etc/caddy/Caddyfile
{
    admin 127.0.0.1:2019
    auto_https off
}

:80 {
    # Bảo vệ toàn bộ trang bằng Basic Auth
    basic_auth {
        ${CADDY_ADMIN_USER} ${HASHED_PASSWORD}
    }

    # Reverse proxy các request API tới backend Flask
    reverse_proxy /api/* http://127.0.0.1:5000

    # Phục vụ các file tĩnh của frontend
    root * /app/frontend
    file_server
}
EOF

echo "Caddyfile đã được tạo thành công."
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf