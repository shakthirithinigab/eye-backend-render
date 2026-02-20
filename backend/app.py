import torch
import os
import numpy as np
import base64
import cv2

from flask import Flask, request, jsonify
from flask_cors import CORS
from transformers import (
    ViTForImageClassification,
    ViTImageProcessor,
    ViTConfig
)
from PIL import Image
from io import BytesIO

# =========================
# FLASK APP
# =========================
app = Flask(__name__)
CORS(app)

# =========================
# DEVICE
# =========================
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print("Using device:", DEVICE)

# =========================
# LOAD CLASS NAMES (FIXED ORDER)
# =========================
DATASET_PATH = "dataset/train"

class_names = sorted([
    d for d in os.listdir(DATASET_PATH)
    if os.path.isdir(os.path.join(DATASET_PATH, d))
])

NUM_CLASSES = len(class_names)
print("Loaded Classes:", class_names)

# =========================
# LOAD MODEL CONFIG
# =========================
config = ViTConfig.from_pretrained(
    "google/vit-base-patch16-224",
    num_labels=NUM_CLASSES
)

config.output_attentions = True  # Enable attention output

# =========================
# LOAD MODEL
# =========================
model = ViTForImageClassification.from_pretrained(
    "google/vit-base-patch16-224",
    config=config,
    ignore_mismatched_sizes=True
)

# Load trained weights safely
state_dict = torch.load("eye_disease_vit.pth", map_location=DEVICE)
model.load_state_dict(state_dict, strict=False)

model.to(DEVICE)
model.eval()

print("✅ Model loaded successfully")

# =========================
# IMAGE PROCESSOR (OFFICIAL)
# =========================
processor = ViTImageProcessor.from_pretrained(
    "google/vit-base-patch16-224"
)

# =========================
# PREPROCESS FUNCTION
# =========================
def preprocess_image(image_bytes):
    image = Image.open(BytesIO(image_bytes)).convert("RGB")
    inputs = processor(images=image, return_tensors="pt")
    return inputs["pixel_values"].to(DEVICE), image

# =========================
# PREDICTION FUNCTION
# =========================
def predict_disease(img_tensor):
    with torch.no_grad():
        outputs = model(img_tensor)
        logits = outputs.logits
        probs = torch.softmax(logits, dim=1)

        confidence, idx = torch.max(probs, 1)

        label = class_names[idx.item()]
        confidence = float(confidence.item() * 100)

    return label, round(confidence, 2)

# =========================
# HEATMAP GENERATION (SAFE)
# =========================
def generate_attention_heatmap(img_tensor, original_image):
    try:
        with torch.no_grad():
            outputs = model(
                img_tensor,
                output_attentions=True
            )

        if outputs.attentions is None:
            return None

        attentions = outputs.attentions[-1]
        attn = attentions[0].mean(dim=0)[0, 1:]

        attn = attn.reshape(14, 14).cpu().numpy()

        attn = cv2.resize(attn, original_image.size)
        attn = (attn - attn.min()) / (attn.max() - attn.min() + 1e-8)
        attn = np.uint8(255 * attn)

        heatmap = cv2.applyColorMap(attn, cv2.COLORMAP_JET)

        original_np = np.array(original_image)
        overlay = cv2.addWeighted(original_np, 0.6, heatmap, 0.4, 0)

        _, buffer = cv2.imencode(".jpg", overlay)
        heatmap_base64 = base64.b64encode(buffer).decode("utf-8")

        return heatmap_base64

    except Exception as e:
        print("Heatmap error:", e)
        return None

# =========================
# API ROUTE
# =========================
@app.route("/predict", methods=["POST"])
def predict():

    if "image" not in request.files:
        return jsonify({"error": "No image uploaded"}), 400

    try:
        file = request.files["image"]
        image_bytes = file.read()

        img_tensor, original_image = preprocess_image(image_bytes)

        disease, confidence = predict_disease(img_tensor)

        heatmap = generate_attention_heatmap(
            img_tensor,
            original_image
        )

        response = {
            "disease": disease,
            "confidence": confidence
        }

        if heatmap is not None:
            response["heatmap"] = heatmap

        return jsonify(response)

    except Exception as e:
        print("Prediction error:", e)
        return jsonify({"error": "Prediction failed"}), 500

# =========================
# RUN SERVER
# =========================

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    app.run(host="0.0.0.0", port=port)

