import os
import requests
import boto3
from botocore.exceptions import NoCredentialsError
from datetime import datetime
from flask import Flask, request, jsonify, send_from_directory

app = Flask(__name__, static_folder='../frontend', static_url_path='')
CADDYFILE_PATH = "/etc/caddy/Caddyfile"
CADDY_ADMIN_API = "http://127.0.0.1:2019"

# Đọc cấu hình S3 từ biến môi trường
S3_BUCKET = os.getenv('S3_BUCKET_NAME')
S3_ENDPOINT = os.getenv('S3_ENDPOINT_URL')
AWS_ACCESS_KEY_ID = os.getenv('AWS_ACCESS_KEY_ID')
AWS_SECRET_ACCESS_KEY = os.getenv('AWS_SECRET_ACCESS_KEY')

s3_client = None
# Kiểm tra các biến cần thiết cho S3-compatible provider
if S3_BUCKET and S3_ENDPOINT and AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY:
    s3_client = boto3.client(
        's3',
        endpoint_url=S3_ENDPOINT,
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY
    )

def backup_to_s3(content):
    if not s3_client:
        return "(Backup skipped: S3 not configured)"
    
    try:
        timestamp = datetime.utcnow().strftime('%Y-%m-%d_%H-%M-%S_UTC')
        file_name = f"Caddyfile_backup_{timestamp}.txt"
        s3_client.put_object(Bucket=S3_BUCKET, Key=file_name, Body=content)
        return f"(Backed up to S3 as {file_name})"
    except NoCredentialsError:
        return "(Backup failed: AWS credentials not valid)"
    except Exception as e:
        return f"(Backup failed: {str(e)})"

# ... (Hàm serve_frontend, get_config và update_config giữ nguyên y hệt phiên bản trước) ...
@app.route('/')
def serve_frontend():
    return send_from_directory(app.static_folder, 'index.html')

@app.route('/api/get-config', methods=['GET'])
def get_config():
    try:
        with open(CADDYFILE_PATH, 'r') as f:
            content = f.read()
        return jsonify({"caddyfile": content})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/update-config', methods=['POST'])
def update_config():
    new_caddyfile_content = request.data.decode('utf-8')
    if not new_caddyfile_content:
        return jsonify({"error": "Empty Caddyfile content"}), 400

    try:
        load_response = requests.post(
            f"{CADDY_ADMIN_API}/load",
            headers={"Content-Type": "text/caddyfile"},
            data=new_caddyfile_content.encode('utf-8')
        )
        load_response.raise_for_status()
    except requests.RequestException as e:
        details = e.response.text if e.response else str(e)
        return jsonify({"error": "Failed to load Caddyfile via API", "details": details}), 500

    try:
        cleaned_content = new_caddyfile_content.replace('\r', '')
        with open(CADDYFILE_PATH, 'w') as f:
            f.write(cleaned_content)
    except Exception as e:
        return jsonify({"error": "Config loaded, but failed to save Caddyfile", "details": str(e)}), 500
        
    backup_status = backup_to_s3(cleaned_content)
    
    return jsonify({"message": f"Caddy config updated successfully! {backup_status}"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
