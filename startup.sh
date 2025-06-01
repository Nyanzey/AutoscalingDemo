#!/bin/bash

# Update system and install Python3 and Git
yum update -y
yum install -y python3 git

# Create app directory
mkdir -p /opt/flask-api

# Set up virtual environment
python3 -m venv /opt/flask-api/sd-env
source /opt/flask-api/sd-env/bin/activate

# Install dependencies
pip install --upgrade pip
pip install flask torch torchvision
pip install diffusers transformers accelerate safetensors

# Write the Flask app
cat > /opt/flask-api/app.py << 'EOF'
from flask import Flask, request, jsonify
from diffusers import StableDiffusionPipeline
import torch
from io import BytesIO
import base64
from PIL import Image
import threading

app = Flask(__name__)
inference_lock = threading.Lock()

pipe = StableDiffusionPipeline.from_pretrained(
    "sd-legacy/stable-diffusion-v1-5",
    torch_dtype=torch.float16
).to("cuda")

@app.route('/generate', methods=['POST'])
def generate():
    data = request.get_json()
    prompt = data.get("prompt", "")
    if not prompt:
        return jsonify({"error": "Prompt is required"}), 400
    with inference_lock:
        image = pipe(prompt).images[0]
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    img_str = base64.b64encode(buffer.getvalue()).decode()
    return jsonify({"image_base64": img_str})

@app.route("/health", methods=["GET"])
def health_check():
    return "OK", 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, threaded=False)
EOF

# Create systemd service
cat > /etc/systemd/system/flask-api.service << 'EOF'
[Unit]
Description=Flask Stable Diffusion API
After=network.target

[Service]
ExecStart=/opt/flask-api/sd-env/bin/python /opt/flask-api/app.py
Restart=always
User=root
WorkingDirectory=/opt/flask-api
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable flask-api
systemctl start flask-api
