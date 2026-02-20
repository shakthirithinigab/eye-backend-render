import torch
import os
from torchvision import datasets, transforms
from torch.utils.data import DataLoader
from transformers import ViTForImageClassification
from sklearn.metrics import accuracy_score, classification_report

DATA_DIR = "dataset"
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print("Using device:", DEVICE)

transform = transforms.Compose([
    transforms.Resize((224,224)),
    transforms.ToTensor(),
    transforms.Normalize([0.5]*3, [0.5]*3)
])

test_data = datasets.ImageFolder(os.path.join(DATA_DIR,"test"), transform=transform)
test_loader = DataLoader(test_data, batch_size=2, shuffle=False, num_workers=0)

num_classes = len(test_data.classes)

model = ViTForImageClassification.from_pretrained(
    "google/vit-base-patch16-224",
    num_labels=num_classes,
    ignore_mismatched_sizes=True
)

model.load_state_dict(torch.load("eye_disease_vit.pth", map_location=DEVICE))
model.to(DEVICE)
model.eval()

preds, trues = [], []

with torch.no_grad():
    for imgs, labels in test_loader:
        imgs, labels = imgs.to(DEVICE), labels.to(DEVICE)
        outputs = model(imgs).logits
        pred = torch.argmax(outputs,1)

        preds.extend(pred.cpu().numpy())
        trues.extend(labels.cpu().numpy())

print("\n✅ Test Accuracy:", accuracy_score(trues, preds))
print("\nClassification Report:\n")
print(classification_report(trues, preds, target_names=test_data.classes))
