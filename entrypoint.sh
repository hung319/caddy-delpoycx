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

# 3. Tạo file Caddyfile với cú pháp route chính xác
echo "Đang tạo file /etc/caddy/Caddyfile..."
cat <<EOF > /etc/caddy/Caddyfile
{
    # Admin API chỉ lắng nghe trên localhost bên trong container để bảo mật
    admin 127.0.0.1:2019
    auto_https off
}

# Server chính, lắng nghe trên port 80
:80 {
    # Bảo vệ toàn bộ trang bằng Basic Auth
    basic_auth {
        ${CADDY_ADMIN_USER} ${HASHED_PASSWORD}
    }

    # SỬA ĐỔI Ở ĐÂY: Thêm khối route
    route {
        # Kích hoạt UI từ plugin
        caddy_admin_ui

        # Reverse proxy các request /api/* tới Admin API nội bộ
        reverse_proxy /api/* 127.0.0.1:2019
    }
}
EOF

echo "Caddyfile đã được tạo thành công."
cat /etc/caddy/Caddyfile

# 4. Khởi chạy Supervisor
echo "Khởi chạy Supervisor để quản lý Caddy và Cloudflared..."
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
