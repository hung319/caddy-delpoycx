import os
import requests
import boto3
from flask import Flask, request, jsonify, send_from_directory

app = Flask(__name__, static_folder='../frontend', static_url_path='')
CADDYFILE_PATH = "/etc/caddy/Caddyfile"
CADDY_ADMIN_API = "http://127.0.0.1:2019"

# Đọc cấu hình S3 từ biến môi trường
S3_BUCKET = os.getenv('S3_BUCKET_NAME')
S3_ENDPOINT = os.getenv('S3_ENDPOINT_URL')
S3_BACKUP_FILENAME = os.getenv('S3_BACKUP_FILENAME', 'Caddyfile.bak') # Lấy tên file, mặc định là 'Caddyfile.bak'
AWS_ACCESS_KEY_ID = os.getenv('AWS_ACCESS_KEY_ID')
AWS_SECRET_ACCESS_KEY = os.getenv('AWS_SECRET_ACCESS_KEY')

s3_client = None
if S3_BUCKET and S3_ENDPOINT and AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY:
    s3_client = boto3.client('s3', endpoint_url=S3_ENDPOINT, aws_access_key_id=AWS_ACCESS_KEY_ID, aws_secret_access_key=AWS_SECRET_ACCESS_KEY)

def backup_to_s3(content):
    if not s3_client:
        return "(Backup skipped: S3 not configured)"
    try:
        # Ghi đè lên file backup cố định
        s3_client.put_object(Bucket=S3_BUCKET, Key=S3_BACKUP_FILENAME, Body=content)
        return f"(Backed up to S3 file: {S3_BACKUP_FILENAME})"
    except Exception as e:
        return f"(Backup failed: {str(e)})"

# ... (Hàm serve_frontend, get_config, update_config giữ nguyên logic chính) ...
@app.route('/')
def serve_frontend():
    return send_from_directory(app.static_folder, 'index.html')

@app.route('/api/get-config', methods=['GET'])
def get_config():
    # ...
    try:
        with open(CADDYFILE_PATH, 'r') as f:
            content = f.read()
        return jsonify({"caddyfile": content})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/update-config', methods=['POST'])
def update_config():
    # ...
    new_caddyfile_content = request.data.decode('utf-8')
    if not new_caddyfile_content:
        return jsonify({"error": "Empty Caddyfile content"}), 400
    try:
        load_response = requests.post(f"{CADDY_ADMIN_API}/load", headers={"Content-Type": "text/caddyfile"}, data=new_caddyfile_content.encode('utf-8'))
        load_response.raise_for_status()
    except requests.RequestException as e:
        details = e.response.text if e.response else str(e)
        return jsonify({"error": "Failed to load Caddyfile via API", "details": details}), 500
    cleaned_content = new_caddyfile_content.replace('\r', '')
    with open(CADDYFILE_PATH, 'w') as f:
        f.write(cleaned_content)
    backup_status = backup_to_s3(cleaned_content)
    return jsonify({"message": f"Caddy config updated successfully! {backup_status}"})

@app.route('/api/restore-s3-backup', methods=['GET'])
def restore_s3_backup():
    """Đọc nội dung của file backup duy nhất từ S3."""
    if not s3_client:
        return jsonify({"error": "S3 not configured"}), 400
    try:
        s3_object = s3_client.get_object(Bucket=S3_BUCKET, Key=S3_BACKUP_FILENAME)
        content = s3_object['Body'].read().decode('utf-8')
        return jsonify({"content": content})
    except s3_client.exceptions.NoSuchKey:
        return jsonify({"error": f"Backup file '{S3_BACKUP_FILENAME}' not found in bucket."}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
