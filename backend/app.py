import os
import requests
from flask import Flask, request, jsonify, send_from_directory

app = Flask(__name__, static_folder='../frontend', static_url_path='')
CADDYFILE_PATH = "/etc/caddy/Caddyfile"
CADDY_ADMIN_API = "http://127.0.0.1:2019"

@app.route('/')
def serve_frontend():
    return send_from_directory(app.static_folder, 'index.html')

@app.route('/api/get-config', methods=['GET'])
def get_config():
    """Đọc và trả về nội dung Caddyfile hiện tại."""
    try:
        with open(CADDYFILE_PATH, 'r') as f:
            content = f.read()
        return jsonify({"caddyfile": content})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# SỬA ĐỔI LỚN Ở ĐÂY
@app.route('/api/update-config', methods=['POST'])
def update_config():
    """Nhận Caddyfile mới và gửi trực tiếp tới API /load."""
    new_caddyfile_content = request.data.decode('utf-8')
    if not new_caddyfile_content:
        return jsonify({"error": "Empty Caddyfile content"}), 400

    # 1. Gửi trực tiếp Caddyfile tới API /load của Caddy
    try:
        load_response = requests.post(
            f"{CADDY_ADMIN_API}/load",
            headers={"Content-Type": "text/caddyfile"},
            data=new_caddyfile_content.encode('utf-8') # Dùng data thay vì json
        )
        # Kiểm tra lỗi
        load_response.raise_for_status()
    except requests.RequestException as e:
        # Lấy chi tiết lỗi từ Caddy nếu có
        details = e.response.text if e.response else str(e)
        return jsonify({"error": "Failed to load Caddyfile via API", "details": details}), 500

    # 2. Lưu lại Caddyfile mới nếu mọi thứ thành công
    try:
        # Chuẩn hóa ký tự xuống dòng trước khi lưu
        cleaned_content = new_caddyfile_content.replace('\r', '')
        with open(CADDYFILE_PATH, 'w') as f:
            f.write(cleaned_content)
    except Exception as e:
        return jsonify({"error": "Config loaded, but failed to save Caddyfile", "details": str(e)}), 500
        
    return jsonify({"message": "Caddy config updated and saved successfully!"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
