from flask import Flask, request, jsonify
from diffusers import StableDiffusion3Pipeline
import torch
from io import BytesIO
import base64
from PIL import Image
import threading

app = Flask(__name__)
inference_lock = threading.Lock()

pipe = StableDiffusion3Pipeline.from_pretrained(
    "stabilityai/stable-diffusion-3.5-medium",
    torch_dtype=torch.float16,
    token="" # Dont forget to add your HuggingFace token here
).to("cuda")

@app.route('/generate', methods=['POST'])
def generate():
    data = request.get_json()
    prompt = data.get("prompt", "")
    inference_steps = data.get("inference_steps", 60)
    guidance_scale = data.get("guidance_scale", 7.5)
    max_sequence_length = data.get("max_sequence_length", 512)
    if not prompt:
        return jsonify({"error": "Prompt is required"}), 400
    with inference_lock:
        image = pipe(prompt, num_inference_steps=inference_steps, guidance_scale=guidance_scale, max_sequence_length=max_sequence_length).images[0]
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    img_str = base64.b64encode(buffer.getvalue()).decode()
    return jsonify({"image_base64": img_str})

@app.route("/health", methods=["GET"])
def health_check():
    return "OK", 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, threaded=False)