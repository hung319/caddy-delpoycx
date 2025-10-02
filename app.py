import os
from flask import Flask, request, Response

app = Flask(__name__)

USERNAME = os.getenv("WEBUI_USER", "admin")
PASSWORD = os.getenv("WEBUI_PASS", "changeme")

def check_auth(username, password):
    return username == USERNAME and password == PASSWORD

def authenticate():
    return Response(
        'Login required', 401,
        {'WWW-Authenticate': 'Basic realm="Login Required"'}
    )

@app.before_request
def require_auth():
    auth = request.authorization
    if not auth or not check_auth(auth.username, auth.password):
        return authenticate()

# --- phần code webui gốc ở đây ---
from flask import render_template
import subprocess

@app.route('/')
def index():
    return render_template("index.html")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)