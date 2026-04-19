<div align="center">

# 🩺 Doctor Gula
### AI-Powered Sugar Intake Tracker for Indonesia

**Point your camera at any packaged food or drink — the app identifies the product, calculates total sugar, and tracks your daily intake against WHO limits in real time.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![TensorFlow Lite](https://img.shields.io/badge/TFLite-MobileNetV2-FF6F00?logo=tensorflow)](https://www.tensorflow.org/lite)
[![Cloudinary](https://img.shields.io/badge/Cloudinary-Dataset%20Pipeline-3448C5)](https://cloudinary.com)
[![Firebase](https://img.shields.io/badge/Firebase-ML%20Delivery-FFCA28?logo=firebase)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://android.com)

</div>

---

## The Problem

Indonesia ranks among the top 10 countries globally for diabetes prevalence. Yet most people have no practical, real-time way to track sugar intake — existing apps require manual lookup, offer no intelligence, and are built for Western markets.

**Doctor Gula** solves this with a camera-first, AI-driven approach built specifically for Indonesian packaged products.

---

## What It Does

| | Feature | Detail |
|---|---|---|
| 🤖 | **On-Device AI Recognition** | MobileNetV2 (TFLite) identifies product brands from packaging photos — no internet required for inference |
| 📊 | **Real-Time Sugar Meter** | Circular progress indicator tracks daily intake against the WHO 50g/day limit with color-coded alerts |
| 🚶 | **Sugar Burn Tracker** | Pedometer integration — sugar meter decreases in real time as you walk (1g = 100 steps, based on 1g = 4 kcal, 1 step = 0.04 kcal) |
| 📋 | **Smart Nutrition Form** | Dynamic form adapts fields for beverages (volume in ml) vs. food (weight in g) with auto-calculated total sugar |
| 📸 | **Silent Dataset Capture** | 9 background frames captured per scan session, auto-compressed and uploaded to retrain the model |
| 🔍 | **Contextual Google Search** | One-tap search pre-filled with product name, variant, and volume for quick sugar lookup |
| 📅 | **Consumption History** | Per-entry cards showing time, product, volume, and sugar — persisted locally with smart daily reset |

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         Flutter App (Dart)                        │
│                                                                    │
│   CameraScreen                                                     │
│       │                                                            │
│       ├─ CameraController ──► TFLiteService                       │
│       │        │                    │                              │
│       │   Silent Frames (9x)   Inference Result                   │
│       │        │                    │                              │
│       └────────┴────────► SugarEditScreen                         │
│                                 │                                  │
│                          SugarEditController                       │
│                           │            │                           │
│                    SugarProvider   CloudinaryService               │
│                    (local state)   (upload JSON pkg)               │
│                           │                                        │
│                    ActivityController                              │
│                    (pedometer + burn calc)                         │
└──────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────▼──────────┐
                    │  Cloudinary Storage │
                    │  JSON + Base64 imgs │
                    └─────────┬──────────┘
                              │
                    ┌─────────▼──────────┐
                    │  Python Pipeline    │
                    │  (Google Colab)     │
                    │                     │
                    │  Collect → Cluster  │
                    │  → Train → Export   │
                    └─────────┬──────────┘
                              │
                    ┌─────────▼──────────┐
                    │  Firebase ML        │
                    │  Model Downloader   │
                    │  (OTA model update) │
                    └─────────┬──────────┘
                              │
                    ┌─────────▼──────────┐
                    │  Flutter App        │
                    │  auto-downloads     │
                    │  updated .tflite    │
                    └────────────────────┘
```

### Key Design Decisions

**Why Cloudinary for dataset storage?**
Each scan uploads a single JSON package containing Base64-encoded images + metadata. This keeps the pipeline serverless — no backend needed. The Python training script queries Cloudinary for all unprocessed entries (`is_processed: false`), downloads them, retrains, and marks them processed.

**Why Firebase only for model delivery?**
Firebase ML Model Downloader handles OTA model updates without requiring a new app release. The bundled `.tflite` in `assets/models/` serves as a fallback if the remote model hasn't downloaded yet.

**Why Provider + ChangeNotifier?**
The app has three reactive data streams: sugar entries, step count, and burn progress. Provider keeps these decoupled and testable without the overhead of BLoC or Riverpod for a project of this scope.

---

## Monorepo Structure

```
sugar-check-ai/
│
├── lib/
│   ├── controllers/          # Business logic — camera, form, sugar state, activity
│   │   ├── camera_controller.dart
│   │   ├── sugar_edit_controller.dart
│   │   ├── sugar_provider.dart
│   │   └── activity_controller.dart
│   │
│   ├── models/               # Type-safe data models
│   │   ├── sugar_entry.dart  # id, brandName, totalSugar, volumeTotal, volumeLabel
│   │   └── scan_result.dart
│   │
│   ├── screens/              # Full-page UI
│   │   ├── home_screen.dart
│   │   ├── scan_screen.dart
│   │   ├── sugar_edit_screen.dart
│   │   └── main_screen.dart
│   │
│   ├── services/             # External integrations
│   │   ├── tflite_service.dart       # MobileNetV2 inference
│   │   ├── cloudinary_service.dart   # Dataset upload pipeline
│   │   └── camera_service.dart
│   │
│   ├── widgets/              # Reusable UI components
│   │   ├── consumption_log_widget.dart   # Today's horizontal card list
│   │   ├── daily_sugar_card.dart         # Animated circular progress
│   │   ├── step_target_widget.dart       # Steps-to-burn progress bar
│   │   ├── loading_overlay_widget.dart
│   │   └── sugar_edit_widgets.dart
│   │
│   └── utils/                # Helpers
│       ├── yuv_converter.dart    # YUV420 → RGB for camera frames
│       └── string_utils.dart
│
├── assets/models/
│   ├── model.tflite          # Bundled fallback model (MobileNetV2, 16 classes)
│   └── labels.txt
│
├── train_model_for_sugar_check_ai/   # Python training pipeline (monorepo)
│   ├── notebooks/
│   │   ├── sugar_checker_collector.ipynb      # Step 1 — data collection
│   │   ├── high_precision_clustering.ipynb    # Step 2 — image clustering
│   │   └── sugar_checker_training.ipynb       # Step 3 — train & export .tflite
│   └── README.md             # Full training guide
│
├── android/
├── .env.example
└── README.md
```

---

## AI Model

| Property | Value |
|---|---|
| Architecture | MobileNetV2 + custom classification head |
| Input | 224 × 224 × 3, normalized to `[-1, 1]` |
| Preprocessing | Center-crop 1:1 → resize → MobileNetV2 normalization |
| Output | Softmax over 16 Indonesian product classes |
| Confidence threshold | 50% — below this, product field is left blank for manual input |
| Val accuracy | ~93% (Phase 3, 250 labeled images) |
| Deployment | Firebase ML (remote, OTA) + bundled `.tflite` (fallback) |

### Recognized Brands (v1 — 16 classes)

> Brand-level classification. Variant recognition (*Oreo Thins*, *Teh Botol Less Sugar*) is the next training milestone as the dataset grows.

`Adem Sari` · `Dum Dum` · `Frisian Flag` · `Hatari` · `Indomaret` · `Indomie` · `Indomilk` · `Interbis` · `Nola` · `Oatside` · `Oreo` · `Teh Botol Sosro` · `Cokelat Cadbury` · `Cokelat Delfi` · `Cokelat SilverQueen` · `Susu Ultra Milk`

### Self-Improving Dataset Loop

Every confirmed scan feeds back into the training pipeline:

```
User scans product
      ↓
App captures 1 primary photo + 9 silent background frames
      ↓
Compressed (primary: 800px/q45, frames: 400px/q30) → Base64 encoded
      ↓
Single JSON package uploaded to Cloudinary:
{
  "product_name": "Teh Botol Sosro",
  "variant_name": "Original",
  "volume_total": 350,
  "sugar_content": 18,
  "ai_confidence": 87.4,
  "user_corrected": false,   ← true if user fixed AI's prediction
  "is_processed": false,     ← Python pipeline picks this up
  "image_base64_list": [...]
}
      ↓
Python script queries is_processed=false → decode → label → retrain
      ↓
New .tflite pushed via Firebase ML → app auto-downloads
```

**False positive detection:** If AI confidence ≥ 80% but the user corrects the product name, the entry is flagged `user_corrected: true` — prioritized in the next retraining cycle as high-signal training data.

---

## Tech Stack

| Layer | Technology | Why |
|---|---|---|
| Framework | Flutter 3 (Dart) | Single codebase, smooth 60fps UI, strong typing |
| AI Inference | TFLite Flutter | On-device, no latency, works offline |
| Model Delivery | Firebase ML Model Downloader | OTA updates without app store release |
| Image Processing | `image` + `flutter_image_compress` | YUV→RGB conversion + multi-level compression |
| Cloud Storage | Cloudinary | Serverless dataset pipeline, free tier sufficient |
| State Management | Provider + ChangeNotifier | Lightweight, reactive, no boilerplate |
| Pedometer | `pedometer` package | Real-time step count for sugar burn tracking |
| Local Storage | `shared_preferences` | Persist daily entries with smart midnight reset |
| Environment | `flutter_dotenv` | Keeps secrets out of source control |

---

## Roadmap

- [x] On-device AI product recognition (MobileNetV2 TFLite)
- [x] Real-time sugar meter with WHO limit
- [x] Silent dataset capture + Cloudinary upload pipeline
- [x] Sugar burn tracker with live pedometer integration
- [x] Consumption history with per-entry volume display
- [ ] **Weekly PDF Report** — daily sugar breakdown vs. WHO limits, exportable
- [ ] **Variant Recognition** — distinguish *Indomie Goreng* from *Indomie Kuah* etc.
- [ ] **Personalized LLM Assistant** — fine-tuned on nutrition + diabetes data, answers *"Is this safe for me today?"*

---

## Setup

### 1. Clone & install
```bash
git clone https://github.com/DhanyDelio/sugar-check-ai.git
cd sugar-check-ai
flutter pub get
```

### 2. Environment
```bash
cp .env.example .env
# Fill in your Cloudinary credentials
```

```env
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_UPLOAD_PRESET=your_unsigned_preset
```

### 3. Firebase
- Add `google-services.json` to `android/app/`
- Enable **ML Kit** and **ML Model Downloader** in your Firebase project
- Upload `model.tflite` to Firebase ML with the model name `sugar_checker`

### 4. Run
```bash
flutter run
```

---

## Training Your Own Model

The full training pipeline lives in [`train_model_for_sugar_check_ai/`](./train_model_for_sugar_check_ai).

Three Google Colab notebooks take you from zero to a deployed `.tflite`:

1. **Collector** — downloads 4,000+ product images from OpenFoodFacts + web crawl
2. **Clustering** — EfficientNetB0 + agglomerative clustering groups images by visual similarity, replacing manual sorting
3. **Training** — MobileNetV2 fine-tuning with class balancing, augmentation, and TFLite export

See [`train_model_for_sugar_check_ai/README.md`](./train_model_for_sugar_check_ai/README.md) for the complete step-by-step guide.

---

## Environment Variables

| Variable | Description |
|---|---|
| `CLOUDINARY_CLOUD_NAME` | Cloud name from Cloudinary Dashboard |
| `CLOUDINARY_UPLOAD_PRESET` | Unsigned upload preset (Settings → Upload) |

> `.env` is gitignored. Never commit it. Use `.env.example` as the template.

---

<div align="center">
Built for Indonesia 🇮🇩 · Flutter + TFLite + Python
</div>
