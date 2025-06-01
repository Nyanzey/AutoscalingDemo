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

@app.route("/health", methods=["GET"])
def health_check():
    return "OK", 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)