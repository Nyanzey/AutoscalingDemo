#!/bin/bash

yum update -y
amazon-linux-extras enable python3.8
yum install -y python38 git

pip3 install flask pillow

# Create app directory
mkdir -p /opt/flask-api
cat > /opt/flask-api/app.py << 'EOF'
from flask import Flask, request, jsonify
from PIL import Image
from io import BytesIO
import base64
import time

app = Flask(__name__)

@app.route('/generate', methods=['POST'])
def generate():
    data = request.get_json()
    prompt = data.get("prompt", "")
    if not prompt:
        return jsonify({"error": "Prompt is required"}), 400
    time.sleep(5)
    img = Image.new('RGB', (512, 512), color='black')
    buffer = BytesIO()
    img.save(buffer, format="PNG")
    img_str = base64.b64encode(buffer.getvalue()).decode()
    return jsonify({"image_base64": img_str})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

# Create systemd service
cat > /etc/systemd/system/flask-api.service << 'EOF'
[Unit]
Description=Flask Image Generation API
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/flask-api/app.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable flask-api
systemctl start flask-api
