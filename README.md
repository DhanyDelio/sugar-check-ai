# Doctor Gula — AI-Powered Sugar Intake Tracker

> A Flutter mobile app that helps users — especially diabetics — monitor their daily sugar intake using on-device AI. Point the camera at any product packaging, and the app automatically detects the product and calculates total sugar content.

---

## The Problem

Indonesia has one of the highest rates of diabetes in Southeast Asia, yet most people have no practical way to track sugar intake in real time. Existing apps require manual lookup and offer no intelligence — Doctor Gula solves this with a camera-first, AI-driven approach.

---

## Features

| Feature | Description |
|---|---|
| 🤖 AI Product Detection | MobileNetV2 (TFLite) recognizes packaged products from camera photos |
| 📊 Sugar Meter | Real-time daily sugar tracking with WHO limit indicator (50g/day) |
| 📋 Smart Nutrition Form | Dynamic form adapts fields for beverages (ml) and food (g) |
| 📸 Silent Dataset Capture | 9 background frames captured per session, auto-uploaded for model retraining |
| 🔍 Google AI Search | One-tap shortcut to look up sugar content via Google |

### Roadmap

- **Activity Gamification** — Each sugar entry triggers a burn suggestion: *"Walk 12 minutes to offset this 10g."* Step progress tracked via accelerometer reduces the meter in real-time.
- **Weekly PDF Report** — Downloadable weekly summary: products consumed, daily sugar breakdown, and comparison against WHO limits.
- **Personalized LLM Assistant** — A fine-tuned model trained on nutrition and diabetes data. Diabetic users can ask: *"Is this safe for me today?"* or *"How much sugar can I still have tonight?"* — turning the app from a passive tracker into a proactive health companion.

---

## System Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Flutter App                        │
│                                                      │
│  ScanScreen → CameraController → TfliteService       │
│       ↓               ↓                              │
│  SugarEditScreen   Silent Frames (9x)                │
│       ↓               ↓                              │
│  SugarEditController → CloudinaryService             │
│       ↓                      ↓                       │
│  SugarProvider          JSON Package Upload          │
│  (local state)      (Base64 images + metadata)       │
└─────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────┐
│              Dataset Pipeline (Python)               │
│                                                      │
│  Cloudinary → Download JSON → Decode Base64          │
│  → Save images → Label → Retrain MobileNetV2         │
│  → Export .tflite → Upload to Firebase ML            │
└─────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────┐
│           App auto-downloads updated model           │
│         via Firebase ML Model Downloader             │
└─────────────────────────────────────────────────────┘
```

### Folder Structure

```
lib/
├── controllers/        Business logic (camera, form, state)
├── core/navigation/    Global NavigationService
├── models/             Type-safe data models (SugarEntry, ScanResult)
├── screens/            UI screens (Home, Scan, Edit)
├── services/           External integrations (TFLite, Cloudinary, Camera)
├── utils/              Helpers (YUV420→RGB conversion, label formatting)
└── widgets/            Reusable components (LoadingOverlay, SugarMeter, etc.)
```

---

## AI Model

| Property | Value |
|---|---|
| Architecture | MobileNetV2 (transfer learning) |
| Input | 224×224 RGB, normalized to [-1, 1] |
| Preprocessing | Center-crop 1:1 → resize → MobileNetV2 normalization |
| Confidence threshold | 50% — below this, field is left empty for manual input |
| Deployment | Firebase ML Model Downloader (remote) + bundled `.tflite` (fallback) |
| Retraining trigger | `is_processed: false` flag in Cloudinary JSON, consumed by Python pipeline |

### False Positive Detection

If AI confidence ≥ 80% but the user corrects the product name, the entry is flagged as `user_corrected: true` — marking it as high-priority training data for the next retraining cycle.

---

## Dataset Pipeline

Every confirmed scan automatically:
1. Compresses primary photo (800px, quality 45) + 9 silent frames (400px, quality 30)
2. Encodes all images to Base64
3. Uploads a single JSON package to Cloudinary:

```json
{
  "product_name": "Coca-Cola",
  "variant_name": "Original",
  "volume_total": 330,
  "sugar_content": 35.0,
  "ai_confidence": 91.2,
  "user_corrected": false,
  "image_base64_list": ["...primary...", "...frame_0...", "...frame_1..."],
  "is_processed": false,
  "timestamp": "1776321816757"
}
```

The Python script queries all entries where `is_processed == false`, downloads and decodes the images, retrains the model, and marks entries as processed.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3 (Dart) |
| AI Inference | TFLite Flutter + Firebase ML Model Downloader |
| Image Processing | `image` + `flutter_image_compress` |
| Cloud Storage | Cloudinary (unsigned upload preset) |
| State Management | Provider + ChangeNotifier |
| Environment Config | `flutter_dotenv` |

---

## Setup

### 1. Clone & install
```bash
git clone https://github.com/DhanyDelio/sugar-check-ai.git
cd sugar-check-ai
flutter pub get
```

### 2. Configure environment
```bash
cp .env.example .env
```
```
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_UPLOAD_PRESET=your_unsigned_preset
```

### 3. Firebase
- Add `google-services.json` to `android/app/`
- Configure Firebase ML Model Downloader in your Firebase project

### 4. Run
```bash
flutter run
```

---

## Environment Variables

| Variable | Description |
|---|---|
| `CLOUDINARY_CLOUD_NAME` | Cloud name from Cloudinary Dashboard |
| `CLOUDINARY_UPLOAD_PRESET` | Unsigned upload preset (Settings → Upload) |

> `.env` is in `.gitignore` — never commit this file. Use `.env.example` as a template.
