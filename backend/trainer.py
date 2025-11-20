import torch
import torch.nn as nn
from torchvision import datasets, transforms, models
from torch.utils.data import DataLoader
import os

# --- CONFIGURATION ---
BATCH_SIZE = 8
CLASSIFIER_LR = 0.001
FINETUNE_LR = 0.0001
EPOCHS = 15
IMG_SIZE = 224
DATA_DIR = "money_dataset_complete"

# --- DATA SETUP ---
train_transform = transforms.Compose(
    [
        transforms.Resize((IMG_SIZE, IMG_SIZE)),
        transforms.RandomHorizontalFlip(),
        transforms.RandomRotation(20),
        transforms.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.2),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ]
)

val_transform = transforms.Compose(
    [
        transforms.Resize((IMG_SIZE, IMG_SIZE)),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ]
)

try:
    train_dataset = datasets.ImageFolder(
        os.path.join(DATA_DIR, "train"), transform=train_transform
    )
    val_dataset = datasets.ImageFolder(
        os.path.join(DATA_DIR, "val"), transform=val_transform
    )
    train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True)
    val_loader = DataLoader(val_dataset, batch_size=BATCH_SIZE, shuffle=False)

    print(f"Successfully loaded datasets from '{DATA_DIR}'.")
    print(f"Found {len(train_dataset.classes)} classes: {train_dataset.classes}")
    num_classes = len(train_dataset.classes)
except FileNotFoundError:
    print(
        f"Error: Directory '{DATA_DIR}' does not exist. Make sure your dataset is set up correctly."
    )
    exit()

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Using device: {device}")

model = models.resnet50(weights=models.ResNet50_Weights.DEFAULT)

# Unfreeze the final convolutional block for fine-tuning
print("\nConfiguring model for fine-tuning...")
for name, child in model.named_children():
    # Unfreeze the final convolutional block ('layer4') and the classifier ('fc')
    if name in ["layer4", "fc"]:
        print(f"✅ Unfreezing and enabling training for layer: {name}")
        for param in child.parameters():
            param.requires_grad = True
    # Keep all other layers frozen
    else:
        for param in child.parameters():
            param.requires_grad = False

# Replace the final classifier head
model.fc = nn.Linear(model.fc.in_features, num_classes)
model = model.to(device)

# --- OPTIMIZER FOR FINE-TUNING ---
params_to_update = [
    {"params": model.layer4.parameters(), "lr": FINETUNE_LR},
    {"params": model.fc.parameters(), "lr": CLASSIFIER_LR},
]
optimizer = torch.optim.Adam(params_to_update)
criterion = nn.CrossEntropyLoss()

print("\n🚀 Starting fine-tuning...")
for epoch in range(EPOCHS):
    model.train()
    running_loss = 0.0
    for images, labels in train_loader:
        images, labels = images.to(device), labels.to(device)

        optimizer.zero_grad()
        outputs = model(images)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()

        running_loss += loss.item()

    train_loss = running_loss / len(train_loader)

    model.eval()
    val_loss = 0.0
    correct = 0
    total = 0
    with torch.no_grad():
        for images, labels in val_loader:
            images, labels = images.to(device), labels.to(device)
            outputs = model(images)
            loss = criterion(outputs, labels)
            val_loss += loss.item()
            _, predicted = torch.max(outputs.data, 1)
            total += labels.size(0)
            correct += (predicted == labels).sum().item()

    val_accuracy = 100 * correct / total
    print(
        f"Epoch [{epoch+1}/{EPOCHS}], Train Loss: {train_loss:.4f}, Val Accuracy: {val_accuracy:.2f}%"
    )

print("✅ Fine-tuning finished!")

save_path = "money_resnet_model.pth"
torch.save(model.state_dict(), save_path)
print(f"\n✅ Model saved successfully to {save_path}")

with open("class_names.txt", "w") as f:
    for c in train_dataset.classes:
        f.write(c + "\n")
print("✅ Class names saved to class_names.txt")
