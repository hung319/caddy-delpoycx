import os
import subprocess
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
    """Đọc và trả về nội dung Caddyfile hiện tại. (Giữ nguyên)"""
    try:
        with open(CADDYFILE_PATH, 'r') as f:
            content = f.read()
        return jsonify({"caddyfile": content})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# SỬA ĐỔI LỚN Ở ĐÂY
@app.route('/api/update-config', methods=['POST'])
def update_config():
    """Nhận Caddyfile, dùng API /adapt để chuyển sang JSON, rồi dùng API /load để cập nhật."""
    new_caddyfile_content = request.data.decode('utf-8')
    if not new_caddyfile_content:
        return jsonify({"error": "Empty Caddyfile content"}), 400

    # Chuẩn hóa ký tự xuống dòng
    new_caddyfile_content = new_caddyfile_content.replace('\r', '')

    # 1. Dùng API /adapt của Caddy để chuyển Caddyfile sang JSON
    try:
        adapt_response = requests.post(
            f"{CADDY_ADMIN_API}/adapt",
            headers={"Content-Type": "text/caddyfile"},
            data=new_caddyfile_content.encode('utf-8')
        )
        adapt_response.raise_for_status()
        json_config = adapt_response.json()
    except requests.RequestException as e:
        # Lấy chi tiết lỗi từ Caddy nếu có
        details = e.response.text if e.response else str(e)
        return jsonify({"error": "Failed to adapt Caddyfile via API", "details": details}), 500

    # 2. Dùng API /load để gửi JSON config mới vào Caddy
    try:
        load_response = requests.post(
            f"{CADDY_ADMIN_API}/load",
            headers={"Content-Type": "application/json"},
            json=json_config
        )
        load_response.raise_for_status()
    except requests.RequestException as e:
        details = e.response.text if e.response else str(e)
        return jsonify({"error": "Failed to load config to Caddy via API", "details": details}), 500

    # 3. Lưu lại Caddyfile mới nếu mọi thứ thành công
    try:
        with open(CADDYFILE_PATH, 'w') as f:
            f.write(new_caddyfile_content)
    except Exception as e:
        return jsonify({"error": "Config loaded, but failed to save Caddyfile", "details": str(e)}), 500
        
    return jsonify({"message": "Caddy config updated and saved successfully!"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
