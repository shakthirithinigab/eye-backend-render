import torch
import os
from torchvision import datasets, transforms
from torch.utils.data import DataLoader
from transformers import ViTForImageClassification
from torch import nn, optim
from sklearn.metrics import accuracy_score

# ---------------- CONFIG ----------------
DATA_DIR = "dataset"
BATCH_SIZE = 2       # safe for CPU
EPOCHS = 5
LR = 2e-5

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print("Using device:", DEVICE)

# ---------------- TRANSFORMS ----------------
train_transform = transforms.Compose([
    transforms.Resize((224,224)),
    transforms.RandomHorizontalFlip(),
    transforms.RandomRotation(10),
    transforms.ToTensor(),
    transforms.Normalize([0.5]*3, [0.5]*3)
])

val_transform = transforms.Compose([
    transforms.Resize((224,224)),
    transforms.ToTensor(),
    transforms.Normalize([0.5]*3, [0.5]*3)
])

# ---------------- DATA ----------------
train_data = datasets.ImageFolder(os.path.join(DATA_DIR,"train"), transform=train_transform)
val_data   = datasets.ImageFolder(os.path.join(DATA_DIR,"val"), transform=val_transform)

train_loader = DataLoader(train_data, batch_size=BATCH_SIZE, shuffle=True, num_workers=0)
val_loader   = DataLoader(val_data, batch_size=BATCH_SIZE, shuffle=False, num_workers=0)

num_classes = len(train_data.classes)
print("Detected Classes:", train_data.classes)

# ---------------- MODEL ----------------
model = ViTForImageClassification.from_pretrained(
    "google/vit-base-patch16-224",
    num_labels=num_classes,
    ignore_mismatched_sizes=True
)

model.to(DEVICE)

criterion = nn.CrossEntropyLoss()
optimizer = optim.AdamW(model.parameters(), lr=LR)

# ---------------- TRAIN ----------------
for epoch in range(EPOCHS):
    model.train()
    train_loss = 0

    print(f"\n--- Epoch {epoch+1}/{EPOCHS} ---")

    for i, (imgs, labels) in enumerate(train_loader):
        imgs, labels = imgs.to(DEVICE), labels.to(DEVICE)

        optimizer.zero_grad()
        outputs = model(imgs).logits
        loss = criterion(outputs, labels)

        loss.backward()
        optimizer.step()

        train_loss += loss.item()

        if i % 5 == 0:
            print(f"Batch {i}/{len(train_loader)} - Loss: {loss.item():.4f}")

    # -------- VALIDATION --------
    model.eval()
    preds, trues = [], []

    with torch.no_grad():
        for imgs, labels in val_loader:
            imgs, labels = imgs.to(DEVICE), labels.to(DEVICE)
            outputs = model(imgs).logits
            pred = torch.argmax(outputs,1)

            preds.extend(pred.cpu().numpy())
            trues.extend(labels.cpu().numpy())

    acc = accuracy_score(trues, preds)
    print(f"Epoch {epoch+1} Finished | Train Loss: {train_loss:.4f} | Val Acc: {acc:.4f}")

# ---------------- SAVE ----------------
torch.save(model.state_dict(), "eye_disease_vit.pth")
print("\n✅ Model Saved as eye_disease_vit.pth")
