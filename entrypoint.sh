#!/bin/bash
set -e

# ... (Các kiểm tra cũ) ...
if [ -z "$CLOUDFLARE_TOKEN" ]; then echo "Lỗi: CLOUDFLARE_TOKEN chưa được thiết lập." >&2; exit 1; fi
if [ -z "$CADDY_ADMIN_PASSWORD" ]; then echo "Lỗi: CADDY_ADMIN_PASSWORD chưa được thiết lập." >&2; exit 1; fi

# Kiểm tra các biến S3 nếu S3_BUCKET_NAME được cung cấp
if [ -n "$S3_BUCKET_NAME" ]; then
  echo "Backup S3 được kích hoạt. Đang kiểm tra các biến môi trường S3..."
  if [ -z "$S3_ENDPOINT_URL" ]; then echo "Lỗi: S3_ENDPOINT_URL chưa được thiết lập." >&2; exit 1; fi
  if [ -z "$AWS_ACCESS_KEY_ID" ]; then echo "Lỗi: AWS_ACCESS_KEY_ID chưa được thiết lập." >&2; exit 1; fi
  if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then echo "Lỗi: AWS_SECRET_ACCESS_KEY chưa được thiết lập." >&2; exit 1; fi
fi

HASHED_PASSWORD=$(caddy hash-password --plaintext "$CADDY_ADMIN_PASSWORD")

# ... (Phần tạo Caddyfile giữ nguyên) ...
cat <<EOF > /etc/caddy/Caddyfile
{
    admin 127.0.0.1:2019
    auto_https off
}

:80 {
    basic_auth {
        \${CADDY_ADMIN_USER} \${HASHED_PASSWORD}
    }
    reverse_proxy /api/* http://127.0.0.1:5000
    root * /app/frontend
    file_server
}
EOF

echo "Caddyfile đã được tạo thành công."
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
