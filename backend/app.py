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
    """Đọc và trả về nội dung Caddyfile hiện tại."""
    try:
        with open(CADDYFILE_PATH, 'r') as f:
            content = f.read()
        return jsonify({"caddyfile": content})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/update-config', methods=['POST'])
def update_config():
    """Nhận Caddyfile mới, adapt sang JSON và load vào Caddy."""
    new_caddyfile_content = request.data.decode('utf-8')
    if not new_caddyfile_content:
        return jsonify({"error": "Empty Caddyfile content"}), 400

    # SỬA ĐỔI Ở ĐÂY: Chuẩn hóa ký tự xuống dòng để loại bỏ '\r'
    new_caddyfile_content = new_caddyfile_content.replace('\r', '')

    # 1. Adapt Caddyfile sang JSON
    try:
        # Chạy lệnh caddy adapt để chuyển đổi
        process = subprocess.run(
            ['caddy', 'adapt', '--config', '-', '--pretty'],
            input=new_caddyfile_content,
            capture_output=True,
            text=True,
            check=True
        )
        json_config = process.stdout
    except subprocess.CalledProcessError as e:
        return jsonify({"error": "Failed to adapt Caddyfile", "details": e.stderr}), 500
    
    # 2. Gửi JSON config tới Caddy Admin API
    try:
        response = requests.post(
            f"{CADDY_ADMIN_API}/load",
            headers={"Content-Type": "application/json"},
            data=json_config
        )
        response.raise_for_status() # Ném lỗi nếu status code là 4xx hoặc 5xx
    except requests.RequestException as e:
        return jsonify({"error": "Failed to post config to Caddy Admin API", "details": str(e)}), 500

    # 3. Lưu lại Caddyfile mới nếu thành công
    try:
        with open(CADDYFILE_PATH, 'w') as f:
            f.write(new_caddyfile_content)
    except Exception as e:
        return jsonify({"error": "Config loaded to Caddy, but failed to save Caddyfile", "details": str(e)}), 500
        
    return jsonify({"message": "Caddy config updated and saved successfully!"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
