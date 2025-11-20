# 🇩🇿 NeuroDZD: Interactive AI Currency Vision

**NeuroDZD** is a real-time, 3D interactive visualization of a Convolutional Neural Network (CNN) classifying Algerian currency. This project bridges Deep Learning and Creative Coding to visualize exactly how an AI "thinks" and processes visual data.

The system analyzes a live webcam feed, locks onto a banknote, and triggers a high-fidelity 3D animation showing the data flow through the neural network layers—from raw pixels to final classification—ending with a live currency conversion.

## 🚀 Features

- **Real-Time Inference:** Fine-tuned **ResNet50** model detecting Algerian Dinar (DZD) banknotes via webcam.
- **3D Visualization:** A high-performance **Processing** engine renders the neural network's internal feature maps as 3D structures.
- **Dynamic Animation:** Visualizes the "pooling" process where data condenses from one layer to the next using particle physics.
- **Live Currency Converter:** Automatically fetches real-time exchange rates (USD/EUR) upon detection.
- **Interactive Controls:** Rotate, pan, and zoom around the 3D neural structures.

## 🛠️ Tech Stack

- **Brain (Backend):** Python 3, PyTorch, Torchvision, OpenCV, Python-OSC.
- **Visuals (Frontend):** Processing 4 (Java), OscP5 Library.
- **Architecture:** Transfer Learning on ResNet50 (ImageNet weights).

## 📂 Dataset & Training

The model is trained to recognize the following classes:

- **Banknotes:** 200, 500, 1000, 2000 DZD.
- **Coins:** 5, 10, 20, 50, 100, 200 DZD.
- **Negative Class:** "Not_Money" (Background noise/objects).

### ⚠️ Important Note on Training Data

The dataset provided in the link below contains **only** the Algerian Dinar images collected by our team.
**To replicate our results, you must also include a negative class.** We utilized the [Intel Image Classification Dataset](https://www.kaggle.com/datasets/puneet6060/intel-image-classification) to populate the `Not_Money` folder. Training without this negative class will result in high false positives.

[**Download the Dinar Dataset on Hugging Face**](https://huggingface.co/datasets/RyZeDZ/neurodzd-algerian-currency)

## ⚙️ Installation

### 1. Clone the Repository

```bash
git clone https://github.com/RyZeDZ/NeuroDZD.git
cd NeuroDZD
```

### 2. Setup Python Backend

```bash
cd backend
python -m venv venv
source venv/bin/activate  # (Windows: venv\Scripts\activate)
pip install -r ../requirements.txt
```

_Note: Download the pre-trained `money_resnet_model.pth` from the **Releases** section of this repository and place it in the `backend/` folder._

### 3. Setup Processing Frontend

1.  Download [Processing 4](https://processing.org/download).
2.  Open `visualization/NeuroDZD_Viz/NeuroDZD_Viz.pde`.
3.  Install the **oscP5** library (`Sketch > Import Library > Add Library`).
4.  **Critical:** Go to `File > Preferences` and increase "Maximum available memory" to **2048MB** or higher.

### 4. Configure Paths

You must link the two applications by setting the shared data path.

1.  **In Python (`live_detector.py`):** Update `OUTPUT_DIR` to the absolute path of the Processing `data` folder.
2.  **In Processing (`NeuroDZD_Viz.pde`):** Update `dataPath` to the exact same path.

## 🎮 Usage

1.  Run the Python script: `python live_detector.py`
2.  Run the Processing sketch.
3.  Show a banknote to the camera.
4.  **Controls:**
    - **Right-Click Drag:** Rotate View
    - **Left-Click Drag:** Pan View
    - **Scroll:** Zoom
    - **[R]:** Replay Animation
    - **[Enter]:** Reset View

## 🤝 Credits & Acknowledgements

- **Lead Developer:** [El Kamel](https://elkamel.dev)
- **Data Collection:** Special thanks to [AI Robotics club](https://airoboticlub.com/) for their assistance in crowdsourcing the currency dataset.
- **External Data:** "Not_Money" class augmented using the Intel Image Classification Dataset.

## 💱 Live Currency Integration

Beyond simple classification, NeuroDZD acts as a smart financial tool:

- **Real-Time Rates:** Upon detecting a banknote (e.g., 2000 DZD), the system fetches live exchange rates via the [open.er-api.com](https://open.er-api.com) API.
- **Auto-Conversion:** It instantly calculates and displays the equivalent value in **USD ($)** and **EUR (€)** alongside the classification.
- **Offline Support:** If the internet connection drops or the API is unreachable, the system seamlessly switches to hardcoded fallback rates to ensure the demonstration never crashes.

## 💡 Inspiration

This project was heavily inspired by the famous **3D Visualization of a Convolutional Neural Network** (originally created for handwritten digits/MNIST).

We wanted to take that concept a step further by applying it to **complex real-world textures** (Algerian Banknotes) and creating a custom implementation from scratch using **Processing** for the rendering engine and **PyTorch** for the backend.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
