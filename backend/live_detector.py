import cv2
import torch
import torchvision.transforms as transforms
from torchvision.models import resnet50
import numpy as np
import time
from pythonosc import udp_client
import os

# --- Configuration ---
# OSC Configuration for sending data to Processing
OSC_IP = "127.0.0.1"
OSC_PORT = 12345
CLIENT = udp_client.SimpleUDPClient(OSC_IP, OSC_PORT)

# Triggering Logic
CONFIDENCE_THRESHOLD = 0.85  # Minimum confidence to consider a detection
DURATION_THRESHOLD = 1.0  # Seconds the detection must be stable

# --- Paths and Data Setup ---
# These paths must point to the files saved by 'train.py' script
MODEL_PATH = "money_resnet_model.pth"
CLASSES_PATH = "class_names.txt"

# Directory where data for Processing will be saved
# IMPORTANT: This must match the 'data' folder inside the Processing sketch
OUTPUT_DIR = "PATH/TO/YOUR/DATA/FOLDER"

# --- Setup ---
if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)
    print(f"Created output directory: {OUTPUT_DIR}")

try:
    with open(CLASSES_PATH, "r") as f:
        CLASS_NAMES = [line.strip() for line in f.readlines()]
except FileNotFoundError:
    print(f"Error: '{CLASSES_PATH}' not found. Please run train.py first.")
    exit()

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Using device: {device}")

# --- Model Loading ---
model = resnet50(weights=None)

num_classes = len(CLASS_NAMES)
model.fc = torch.nn.Linear(model.fc.in_features, num_classes)

try:
    model.load_state_dict(torch.load(MODEL_PATH, map_location=device))
except FileNotFoundError:
    print(f"Error: Model file '{MODEL_PATH}' not found. Please run train.py first.")
    exit()

model.to(device)
model.eval()
print(f"Successfully loaded fine-tuned model for {num_classes} classes.")

# --- Image Transformations ---
# This MUST be identical to the 'val_transform' from the training script to ensure the model sees data in the format it expects.
live_transform = transforms.Compose(
    [
        transforms.ToPILImage(),
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ]
)

# --- Feature Map Extraction using PyTorch Hooks ---
feature_maps = {}


def get_feature_map_hook(name):
    """Returns a hook function that saves the output of a layer."""

    def hook(model, input, output):
        feature_maps[name] = output.detach().cpu().numpy()

    return hook


model.conv1.register_forward_hook(get_feature_map_hook("low_level"))  # First conv layer
model.layer2.register_forward_hook(
    get_feature_map_hook("mid_level")
)  # After a few blocks
model.layer4.register_forward_hook(
    get_feature_map_hook("high_level")
)  # The last, fine-tuned block

# --- Main Application Logic ---
cap = cv2.VideoCapture(0)
if not cap.isOpened():
    print("Error: Could not open webcam.")
    exit()

last_detection = None
detection_start_time = None
locked_on = False

print("\nScript is running. Point webcam at currency...")

while True:
    ret, frame = cap.read()
    if not ret:
        break

    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

    input_tensor = live_transform(rgb_frame).unsqueeze(0).to(device)

    with torch.no_grad():
        outputs = model(input_tensor)
        probabilities = torch.nn.functional.softmax(outputs, dim=1)
        confidence, predicted_idx = torch.max(probabilities, 1)

    confidence = confidence.item()
    predicted_class = CLASS_NAMES[predicted_idx.item()]

    # --- Trigger Logic ---
    if predicted_class != "Not_Money" and confidence > CONFIDENCE_THRESHOLD:
        if predicted_class == last_detection:
            if time.time() - detection_start_time >= DURATION_THRESHOLD:
                if not locked_on:
                    print(f"--- LOCK-ON: {predicted_class} ---")
                    locked_on = True

                    # --- Data Extraction and Saving ---
                    gray_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                    resized_gray = cv2.resize(gray_frame, (224, 224))
                    cv2.imwrite(os.path.join(OUTPUT_DIR, "input.png"), resized_gray)

                    NUM_MAPS_TO_SAVE = 8
                    for name, fmap in feature_maps.items():
                        num_available = fmap.shape[1]
                        maps_to_save = fmap[
                            0, : min(NUM_MAPS_TO_SAVE, num_available), :, :
                        ]

                        (depth, height, width) = maps_to_save.shape
                        reshaped_maps = maps_to_save.reshape(depth * height, width)

                        np.savetxt(
                            os.path.join(OUTPUT_DIR, f"{name}.csv"),
                            reshaped_maps,
                            delimiter=",",
                        )

                    CLIENT.send_message("/trigger", predicted_class)
                    print(f"Data saved and trigger sent for {predicted_class}.")
        else:
            last_detection = predicted_class
            detection_start_time = time.time()
            locked_on = False
    else:
        if last_detection is not None:
            print("...Lost track, resetting.")
        last_detection = None
        locked_on = False

    # --- Display the live feed with detection info for debugging ---
    display_text = f"Scanning..."
    if last_detection:
        display_text = f"Detecting: {last_detection} ({confidence:.2f})"
        if locked_on:
            display_text = f"LOCKED: {last_detection}"

    cv2.putText(
        frame, display_text, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2
    )
    cv2.imshow("Live Feed - Press Q to Quit", frame)

    if cv2.waitKey(1) & 0xFF == ord("q"):
        break

# --- Cleanup ---
cap.release()
cv2.destroyAllWindows()
print("Application closed.")
