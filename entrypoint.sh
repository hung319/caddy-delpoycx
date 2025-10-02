#!/bin/bash
set -e # Thoát ngay lập tức nếu có lỗi

# 1. Kiểm tra các biến môi trường quan trọng
if [ -z "$CLOUDFLARE_TOKEN" ]; then
  echo "Lỗi: Biến môi trường CLOUDFLARE_TOKEN chưa được thiết lập." >&2
  exit 1
fi

if [ -z "$CADDY_ADMIN_PASSWORD" ]; then
  echo "Lỗi: Biến môi trường CADDY_ADMIN_PASSWORD chưa được thiết lập." >&2
  exit 1
fi

# 2. Hash mật khẩu admin bằng Caddy
echo "Đang hash mật khẩu cho Caddy admin..."
HASHED_PASSWORD=$(caddy hash-password --plaintext "$CADDY_ADMIN_PASSWORD")

# 3. Tạo file Caddyfile
# Cấu hình này rất an toàn:
# - Admin API chỉ lắng nghe trên localhost (127.0.0.1) bên trong container.
# - Web server chính (cổng 80) sẽ reverse proxy tới Admin API qua đường dẫn /api/.
# - Toàn bộ web server (bao gồm cả UI và API) được bảo vệ bằng Basic Auth.
echo "Đang tạo file /etc/caddy/Caddyfile..."
cat <<EOF > /etc/caddy/Caddyfile
{
    # Bật Admin API, chỉ cho phép truy cập từ bên trong container
    admin 127.0.0.1:2019
    # Tự động cấp chứng chỉ HTTPS cho domain của bạn
    auto_https off
}

# Web server chính sẽ được Cloudflare Tunnel trỏ tới
http://${CADDY_DOMAIN}:80 {
    # Bảo vệ toàn bộ trang bằng Basic Auth
    basic_auth {
        ${CADDY_ADMIN_USER} ${HASHED_PASSWORD}
    }

    # Route tới Admin API
    route /api/* {
        reverse_proxy 127.0.0.1:2019
    }

    # Route phục vụ các file tĩnh của Admin UI
    route {
        root * /var/www/html/caddy-ui
        file_server
    }
}
EOF

echo "Caddyfile đã được tạo thành công."
cat /etc/caddy/Caddyfile

# 4. Khởi chạy Supervisor
# 'exec' sẽ thay thế tiến trình shell bằng supervisord, đảm bảo tín hiệu (signals) được xử lý đúng cách.
echo "Khởi chạy Supervisor để quản lý Caddy và Cloudflared..."
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf