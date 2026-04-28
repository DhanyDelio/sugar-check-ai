<div align="center">

# 🩺 Doctor Gula

### Indonesia has 19 million diabetics. Most don't track sugar because it's too hard. This app uses a custom-trained on-device AI to make it instant — point camera, get sugar content, no typing.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![TensorFlow Lite](https://img.shields.io/badge/TFLite-MobileNetV2-FF6F00?logo=tensorflow)](https://www.tensorflow.org/lite)
[![AWS Amplify](https://img.shields.io/badge/AWS-Amplify%20%2B%20S3-FF9900?logo=amazonaws)](https://aws.amazon.com/amplify/)
[![Firebase](https://img.shields.io/badge/Firebase-ML%20Delivery-FFCA28?logo=firebase)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://android.com)

https://github.com/user-attachments/assets/10cc03a7-1fa4-47e6-bf1a-441dbad71873

</div>

---

## The Core Problem the AI Solves

Existing sugar tracking apps fail because they require manual lookup. Users have to search, scroll, and type — for every single product, every single day. Nobody does it.

The only way to make tracking actually happen is to **eliminate the input step entirely**.

That's what the AI does. It identifies the product from a photo. The user does nothing except point their camera.

But no model existed for Indonesian packaged goods — so it had to be built from scratch.

---

## Building the AI From Scratch

There was no labeled dataset for Indonesian products. The entire data pipeline was designed and built as part of this project:

```
Problem: no labeled dataset for Indonesian packaged goods
        │
        ▼
Downloaded 4.4M product records from OpenFoodFacts (HuggingFace)
Filtered: ~7,953 Indonesia-specific entries
Downloaded: 4,000+ product images
Web-crawled: 14 product categories (DuckDuckGo + Google)
        │
        ▼
EfficientNetB0 → 1280-dim feature vectors → L2 normalize
Agglomerative Clustering (distance_threshold=0.15)
Cosine similarity filter (>0.92) → pure, clean clusters
        │
        ▼
Manual review: rename cluster_039/ → Indomie/
16 labeled classes, ~250 images
        │
        ▼
MobileNetV2 fine-tuning
Frozen backbone + custom head (Dense 512→256→N)
Balanced class weights + aggressive augmentation
EarlyStopping + ReduceLROnPlateau
        │
        ▼
~93% validation accuracy
Export → .tflite → deployed on-device
```

The full pipeline — 3 Google Colab notebooks — lives in [`train_model_for_sugar_check_ai/`](./train_model_for_sugar_check_ai).

---

## The Model Gets Smarter With Every User Scan

Every confirmed scan silently captures 10 photos (1 primary + 9 background frames) and uploads them to AWS S3 with a sidecar JSON for the training pipeline:

```
User confirms a scan
        │
        ├── 1 primary photo (800px, quality 45)
        └── 9 silent background frames (400px, quality 30)
                │
                ▼
        Compressed → uploaded to AWS S3
        Path: public/datasets/[product]/[variant]/[volume]/[filename].jpg
        Sidecar: [filename].json  ← metadata for training pipeline

{
  "product_name": "teh-botol-sosro",
  "sugar_content": 18,
  "ai_confidence": 87.4,
  "user_corrected": false,
  "is_processed": false,
  "timestamp": "1776321816757"
}
                │
                ▼
        Python pipeline: query is_processed=false
        → download from S3 → retrain model → mark processed
                │
                ▼
        New .tflite → Firebase ML → app auto-downloads
```

**Physical clustering via S3 path** — products with the same name/variant/volume automatically land in the same S3 folder. No manual clustering needed as the dataset grows.

**False positive signal** — If AI confidence ≥ 80% but user corrects the product name → `user_corrected: true` → high-priority training data.

---

## Model Specs

| Property | Value |
|---|---|
| Architecture | MobileNetV2 (frozen) + Dense(512) + Dense(256) + Softmax |
| Input | 224 × 224 × 3, normalized to `[-1, 1]` |
| Preprocessing | Center-crop 1:1 → resize → MobileNetV2 normalization |
| Output | Softmax over 16 Indonesian product classes |
| Confidence threshold | 50% — below this, field is left blank for manual input |
| Val accuracy | ~93% (Phase 3, 250 labeled images) |
| Deployment | Firebase ML (OTA) + bundled `.tflite` (offline fallback) |

**Recognized brands (v1 — 16 classes):**

`Adem Sari` · `Dum Dum` · `Frisian Flag` · `Hatari` · `Indomaret` · `Indomie` · `Indomilk` · `Interbis` · `Nola` · `Oatside` · `Oreo` · `Teh Botol Sosro` · `Cokelat Cadbury` · `Cokelat Delfi` · `Cokelat SilverQueen` · `Susu Ultra Milk`

> Brand-level today. Variant recognition is the next milestone as the dataset grows through user scans.

---

## What the App Does With the AI Output

| | Feature | Detail |
|---|---|---|
| 📊 | **Real-Time Sugar Meter** | Circular progress tracks daily net sugar vs. WHO 50g/day — color shifts green → orange → red |
| 📋 | **Smart Nutrition Form** | Pre-filled from AI prediction. Adapts fields for beverages (ml) vs. food (g). Auto-calculates total sugar |
| 🚶 | **Activity Offset (Hidden Credit)** | Steps accumulate a hidden sugar credit (1,000 steps = 1g, capped at 15g/day). Credit is automatically deducted from the next scan |
| 📅 | **Consumption History** | Per-entry cards show raw label sugar + volume — persisted locally with smart midnight reset |
| 🔍 | **Contextual Search** | One-tap Google search pre-filled with product + variant + volume |

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         Flutter App (Dart)                        │
│                                                                    │
│   CameraScreen                                                     │
│       │                                                            │
│       ├─ CameraController ──► TFLiteService ◄── model.tflite     │
│       │        │                    │                              │
│       │   Silent Frames (9x)   Inference Result                   │
│       │        │                    │                              │
│       └────────┴────────► SugarEditScreen                         │
│                                 │                                  │
│                          SugarEditController                       │
│                           │            │                           │
│                    SugarProvider   AwsStorageService               │
│                    (net meter)    (S3 upload + sidecar JSON)       │
│                           │                                        │
│                    ActivityController                              │
│                    (step credit system)                            │
└──────────────────────────────────────────────────────────────────┘
          │                                    │
          ▼                                    ▼
  SharedPreferences                       AWS S3
  (daily entries,              public/datasets/[product]/[variant]/
   step credit,                         [volume]/[filename].jpg
   midnight reset)                       [filename].json (sidecar)
                                               │
                                    ┌──────────▼──────────┐
                                    │   Python Pipeline    │
                                    │   Collect → Train    │
                                    │   → Export .tflite   │
                                    └──────────┬──────────┘
                                               │
                                    ┌──────────▼──────────┐
                                    │   Firebase ML        │
                                    │   OTA .tflite        │
                                    └──────────┬──────────┘
                                               │
                                         Flutter App
                                       auto-downloads
```

### Activity Offset — Hidden Credit System

```
User walks → steps accumulate in background (foreground service)
        │
1,000 steps = 1g credit  (conservative — prevents over-estimation)
Max credit = 15g/day     (safety cap — prevents exercise compensation)
        │
User scans → processSugarIntake(rawGrams)
  appliedCredit stored in SugarEntry.appliedCredit
  netSugar = rawGrams - appliedCredit → shown on meter
  rawGrams always preserved → shown on history card
```

### Key Design Decisions

**AWS S3 + physical clustering** — Each scan uploads photos directly to a structured S3 path. Products with the same name/variant/volume auto-group into the same folder. No clustering step needed as data grows.

**Firebase only for model delivery** — OTA updates without a new app release. Bundled `.tflite` is the offline fallback.

**UUID-based anonymous device ID** — No login required. Each device gets a persistent UUID stored in SharedPreferences, used as `user_id` in S3 metadata.

**Provider + ChangeNotifier** — Three reactive streams (sugar entries, step credit, activity) that need to stay in sync.

---

## Monorepo Structure

```
sugar-check-ai/
├── lib/
│   ├── controllers/
│   │   ├── camera_controller.dart        # Camera + silent frame capture + flip
│   │   ├── sugar_edit_controller.dart    # Form logic + upload orchestration
│   │   ├── sugar_provider.dart           # Daily entries state + persistence
│   │   └── activity_controller.dart      # Pedometer + sugar credit system
│   ├── core/
│   │   ├── app_colors.dart               # Centralized color constants
│   │   └── navigation/navigation_service.dart
│   ├── models/
│   │   ├── sugar_entry.dart              # rawSugarGrams, appliedCredit, volumeLabel
│   │   └── scan_result.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── scan_screen.dart
│   │   ├── sugar_edit_screen.dart
│   │   └── main_screen.dart
│   ├── services/
│   │   ├── tflite_service.dart           # MobileNetV2 inference
│   │   ├── aws_storage_service.dart      # S3 upload + sidecar JSON
│   │   ├── user_id_service.dart          # Persistent anonymous UUID
│   │   └── battery_optimization_service.dart
│   ├── widgets/
│   │   ├── consumption_log_widget.dart
│   │   ├── daily_sugar_card.dart
│   │   ├── step_target_widget.dart
│   │   ├── loading_overlay_widget.dart
│   │   └── sugar_edit_widgets.dart
│   └── utils/
│       ├── image_utils.dart              # YUV420 → RGB conversion
│       └── string_utils.dart
├── assets/models/
│   ├── model.tflite                      # Bundled fallback (MobileNetV2, 16 classes)
│   └── labels.txt
├── train_model_for_sugar_check_ai/
│   ├── notebooks/
│   └── README.md
├── amplifyconfiguration.dart             # Generated by Amplify CLI (gitignored)
├── .env.example
└── README.md
```

---

## Tech Stack

| Layer | Technology | Why |
|---|---|---|
| Framework | Flutter 3 (Dart) | Single codebase, 60fps UI, strong typing |
| AI Inference | TFLite Flutter | On-device, zero latency, fully offline |
| Model Delivery | Firebase ML Model Downloader | OTA updates without app store release |
| Dataset Storage | AWS S3 + Amplify | Physical clustering via path structure, scalable |
| Auth | AWS Cognito (via Amplify) | Anonymous device identity |
| Image Processing | `image` + `flutter_image_compress` | YUV→RGB + parallel compression |
| State Management | Provider + ChangeNotifier | Lightweight, reactive, decoupled |
| Pedometer | `pedometer` + `flutter_foreground_task` | Background step counting, auto-restart on boot |
| Local Storage | `shared_preferences` | Daily entries + step credit + device UUID |
| Environment | `flutter_dotenv` | Secrets out of source control |

---

## Roadmap

- [x] Custom-trained on-device AI (MobileNetV2, 16 classes, ~93% val accuracy)
- [x] Self-improving dataset loop (silent capture → AWS S3 → retrain → OTA)
- [x] Real-time sugar meter with WHO daily limit (50g max, 25g ideal)
- [x] Activity offset — hidden credit system (1,000 steps = 1g, 15g/day cap)
- [x] Medical safety: raw label sugar preserved, net sugar shown on meter
- [x] Consumption history with per-entry volume
- [x] Background step counting via foreground service (Realme/OPPO compatible)
- [x] Anonymous device UUID — no login required
- [ ] **Variant Recognition** — *Indomie Goreng* vs *Indomie Kuah* etc.
- [ ] **Weekly PDF Report** — daily breakdown vs. WHO limits
- [ ] **Personalized LLM Assistant** — *"Is this safe for me today?"*

---

## Setup

### 1. Clone & install
```bash
git clone https://github.com/DhanyDelio/sugar-check-ai.git
cd sugar-check-ai
flutter pub get
```

### 2. AWS Amplify
```bash
# Install Amplify CLI if not already installed
npm install -g @aws-amplify/cli

# Pull existing Amplify backend config
amplify pull
# This generates lib/amplifyconfiguration.dart (gitignored)
```

### 3. Firebase
- Add `google-services.json` to `android/app/`
- Enable **ML Kit** + **ML Model Downloader** in Firebase Console
- Upload `model.tflite` to Firebase ML with model name `sugar_checker`

### 4. Run
```bash
flutter run
```

---

## Training the Model

Full pipeline in [`train_model_for_sugar_check_ai/`](./train_model_for_sugar_check_ai) — 3 Colab notebooks, zero local setup.

See [`train_model_for_sugar_check_ai/README.md`](./train_model_for_sugar_check_ai/README.md) for the complete guide.

---

<div align="center">
Built for Indonesia 🇮🇩 · Flutter + TFLite + AWS + Python
</div>
