<div align="center">

# 🩺 Doctor Gula

### Indonesia has 19 million diabetics. Most don't track sugar because it's too hard. This app uses a custom-trained on-device AI to make it instant — point camera, get sugar content, no typing.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![TensorFlow Lite](https://img.shields.io/badge/TFLite-MobileNetV2-FF6F00?logo=tensorflow)](https://www.tensorflow.org/lite)
[![Cloudinary](https://img.shields.io/badge/Cloudinary-Dataset%20Pipeline-3448C5)](https://cloudinary.com)
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

The AI doesn't stop improving after deployment. Every confirmed scan feeds new labeled data back into the training pipeline automatically:

```
User confirms a scan
        │
        ├── 1 primary photo (800px, quality 45)
        └── 9 silent background frames (400px, quality 30)
                │
                ▼
        Compressed → Base64 → single JSON package → Cloudinary

{
  "product_name": "Teh Botol Sosro",
  "sugar_content": 18,
  "ai_confidence": 87.4,
  "user_corrected": false,   ← true = high-priority training signal
  "is_processed": false,     ← Python pipeline picks this up
  "image_base64_list": [...]
}
                │
                ▼
        Python script: query is_processed=false
        → decode images → retrain model → mark processed
                │
                ▼
        New .tflite → Firebase ML → app auto-downloads
```

**False positive signal:** If AI confidence ≥ 80% but the user corrects the product name → flagged `user_corrected: true` → prioritized as high-signal data in the next training cycle. The model learns from its own mistakes.

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

> Brand-level today. Variant recognition (*Indomie Goreng* vs *Indomie Kuah*) is the next milestone as the dataset grows through user scans.

---

## What the App Does With the AI Output

Once the model identifies the product, the rest of the app takes over:

| | Feature | Detail |
|---|---|---|
| 📊 | **Real-Time Sugar Meter** | Circular progress tracks daily net sugar vs. WHO 50g/day — color shifts green → orange → red |
| 📋 | **Smart Nutrition Form** | Pre-filled from AI prediction. Adapts fields for beverages (ml) vs. food (g). Auto-calculates total sugar |
| 🚶 | **Activity Offset (Hidden Credit)** | Steps accumulate a hidden sugar credit (1,000 steps = 1g, capped at 15g/day). Credit is automatically deducted from the next scan — the meter only rises by the net amount |
| 📅 | **Consumption History** | Per-entry cards show raw label sugar (for packaging verification) + volume — persisted locally with smart midnight reset |
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
│                    SugarProvider   CloudinaryService               │
│                    (net meter)    (upload JSON pkg)                │
│                           │                                        │
│                    ActivityController                              │
│                    (step credit system)                            │
└──────────────────────────────────────────────────────────────────┘
          │                                    │
          ▼                                    ▼
  SharedPreferences                    Cloudinary Storage
  (daily entries,                      (JSON + Base64 imgs)
   smart reset)                                │
                                    ┌──────────▼──────────┐
                                    │   Python Pipeline    │
                                    │   Collect → Cluster  │
                                    │   → Train → Export   │
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

Steps do not decrease the sugar meter in real-time. Instead they accumulate a hidden **sugar credit** that is applied at the moment of the next product scan:

```
User walks throughout the day
        │
        ▼
ActivityController accumulates steps via two layers:
  1. Foreground Service (flutter_foreground_task) — runs in a separate isolate,
     keeps pedometer alive even when screen is off or app is backgrounded.
     Writes steps to SharedPreferences every update.
     Auto-restarts on device reboot.
  2. Main isolate pedometer — updates UI when app is in foreground.
     Sync timer (10s) reads steps written by foreground isolate.

1,000 steps = 1g credit  (conservative ratio — prevents over-estimation)
Max credit = 15g/day     (safety cap — prevents exercise compensation behaviour)
        │
        ▼
User scans a product → 18g raw sugar on label
        │
        ▼
SugarProvider.addEntry() calls processSugarIntake(18g)
  availableCredit = 5g
  appliedCredit   = 5g   → stored in SugarEntry.appliedCredit
  netSugar        = 13g  → stored as SugarEntry.totalSugar (computed)
        │
        ├── Dashboard meter  += 13g  (net — what user is accountable for)
        └── History card shows 18g  (raw — matches product label)
```

**Medical safety rationale:**
- 1,000:1 ratio is intentionally conservative for low-intensity walking
- 15g daily cap prevents the well-documented "exercise compensation" effect
- Raw label sugar is always preserved in `rawSugarGrams` — no data is lost
- A medical disclaimer is embedded in `ActivityController.medicalDisclaimer`

### Key Design Decisions

**Cloudinary as dataset pipeline** — Each scan uploads one JSON package (images + metadata). No backend server. Python polls `is_processed: false`, processes, marks done. Serverless, zero cost during development.

**Firebase only for model delivery** — OTA updates without a new app release. Bundled `.tflite` is the offline fallback.

**Provider + ChangeNotifier** — Three reactive streams (sugar entries, step credit, burn progress) that need to stay in sync. Provider is the right weight for this scope.

---

## Monorepo Structure

```
sugar-check-ai/
├── lib/
│   ├── controllers/
│   │   ├── camera_controller.dart        # Camera + silent frame capture
│   │   ├── sugar_edit_controller.dart    # Form logic + upload orchestration
│   │   ├── sugar_provider.dart           # Daily entries state + persistence
│   │   └── activity_controller.dart      # Pedometer + sugar burn calculation
│   ├── models/
│   │   ├── sugar_entry.dart              # id, brandName, totalSugar, volumeTotal, volumeLabel
│   │   └── scan_result.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── scan_screen.dart
│   │   ├── sugar_edit_screen.dart
│   │   └── main_screen.dart
│   ├── services/
│   │   ├── tflite_service.dart           # MobileNetV2 inference + confidence threshold
│   │   ├── cloudinary_service.dart       # Compress → Base64 → JSON upload
│   │   └── camera_service.dart
│   ├── widgets/
│   │   ├── consumption_log_widget.dart
│   │   ├── daily_sugar_card.dart
│   │   ├── step_target_widget.dart
│   │   ├── loading_overlay_widget.dart
│   │   └── sugar_edit_widgets.dart
│   └── utils/
│       ├── yuv_converter.dart            # YUV420 → RGB for live camera frames
│       └── string_utils.dart
├── assets/models/
│   ├── model.tflite                      # Bundled fallback (MobileNetV2, 16 classes)
│   └── labels.txt
├── train_model_for_sugar_check_ai/       # Full training pipeline
│   ├── notebooks/
│   │   ├── sugar_checker_collector.ipynb
│   │   ├── high_precision_clustering.ipynb
│   │   └── sugar_checker_training.ipynb
│   └── README.md
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
| Image Processing | `image` + `flutter_image_compress` | YUV→RGB + multi-level compression |
| Dataset Storage | Cloudinary | Serverless pipeline, no backend needed |
| State Management | Provider + ChangeNotifier | Lightweight, reactive, decoupled |
| Pedometer | `pedometer` + `flutter_foreground_task` | Background step counting with foreground service |
| Local Storage | `shared_preferences` | Daily entries + step credit with smart midnight reset |
| Environment | `flutter_dotenv` | Secrets out of source control |

---

## Roadmap

- [x] Custom-trained on-device AI (MobileNetV2, 16 classes, ~93% val accuracy)
- [x] Self-improving dataset loop (silent capture → Cloudinary → retrain → OTA)
- [x] Real-time sugar meter with WHO daily limit (50g max, 25g ideal)
- [x] Activity offset — hidden credit system (1,000 steps = 1g, 15g/day cap)
- [x] Medical safety: raw label sugar preserved, net sugar shown on meter
- [x] Consumption history with per-entry volume
- [ ] **Variant Recognition** — *Indomie Goreng* vs *Indomie Kuah*, *Teh Botol Less Sugar* etc.
- [ ] **Weekly PDF Report** — daily breakdown vs. WHO limits, exportable
- [ ] **Personalized LLM Assistant** — *"Is this safe for me today?"* based on intake history

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
```
```env
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_UPLOAD_PRESET=your_unsigned_preset
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

## Environment Variables

| Variable | Description |
|---|---|
| `CLOUDINARY_CLOUD_NAME` | Cloud name from Cloudinary Dashboard |
| `CLOUDINARY_UPLOAD_PRESET` | Unsigned upload preset (Settings → Upload) |

> `.env` is gitignored. Use `.env.example` as the template.

---

<div align="center">
Built for Indonesia 🇮🇩 · Flutter + TFLite + Python
</div>

The entire app is built around one core capability: **a custom-trained MobileNetV2 model that recognizes Indonesian food and beverage packaging from a photo**.

Everything else — the sugar meter, the burn tracker, the history cards — only exists because the AI makes the data entry instant.

### How the model was built

This isn't a pre-trained classifier with a new head slapped on. The dataset was built from zero:

```
No labeled dataset existed for Indonesian products
        │
        ▼
Downloaded 4.4M product records from OpenFoodFacts (HuggingFace)
        │
        ▼
Filtered ~7,953 Indonesia-specific products
        │
        ▼
Downloaded 4,000+ product images + web-crawled 14 categories
        │
        ▼
EfficientNetB0 feature extraction → Agglomerative Clustering
(groups visually similar images without manual sorting)
        │
        ▼
Cosine similarity filter (>0.92) → clean, pure clusters
        │
        ▼
Manual review: rename cluster_039/ → Indomie/, etc.
        │
        ▼
MobileNetV2 fine-tuning: 16 classes, 250 images, ~93% val accuracy
        │
        ▼
Export → .tflite → bundled in app + delivered via Firebase ML
```

The full pipeline — 3 Google Colab notebooks — lives in [`train_model_for_sugar_check_ai/`](./train_model_for_sugar_check_ai).

### The model gets smarter with every scan

Every time a user confirms a scan, the app silently captures 9 background frames alongside the primary photo. All images are compressed, Base64-encoded, and uploaded as a single JSON package to Cloudinary:

```json
{
  "product_name": "Teh Botol Sosro",
  "variant_name": "Original",
  "volume_total": 350,
  "sugar_content": 18,
  "ai_confidence": 87.4,
  "user_corrected": false,
  "is_processed": false,
  "image_base64_list": ["...primary...", "...frame_0...", "...frame_8..."]
}
```

The Python pipeline queries `is_processed: false`, decodes the images, retrains the model, and pushes the new `.tflite` via Firebase ML — which the app downloads automatically on next launch.

**False positive signal:** If AI confidence ≥ 80% but the user corrects the product name, the entry is flagged `user_corrected: true` — treated as high-priority training data in the next cycle.

### Model specs

| Property | Value |
|---|---|
| Architecture | MobileNetV2 (frozen backbone) + custom head |
| Input | 224 × 224 × 3, normalized to `[-1, 1]` |
| Preprocessing | Center-crop 1:1 → resize → MobileNetV2 normalization |
| Output | Softmax over 16 Indonesian product classes |
| Confidence threshold | 50% — below this, field is left blank for manual input |
| Val accuracy | ~93% (Phase 3, 250 labeled images) |
| Deployment | Firebase ML (OTA) + bundled `.tflite` (offline fallback) |

**Recognized brands (v1):**
`Adem Sari` · `Dum Dum` · `Frisian Flag` · `Hatari` · `Indomaret` · `Indomie` · `Indomilk` · `Interbis` · `Nola` · `Oatside` · `Oreo` · `Teh Botol Sosro` · `Cokelat Cadbury` · `Cokelat Delfi` · `Cokelat SilverQueen` · `Susu Ultra Milk`

> Brand-level classification today. Variant recognition (*Indomie Goreng* vs *Indomie Kuah*) is the next training milestone as the dataset grows through user scans.

---

## What the App Does With the AI Output

Once the model identifies the product, the app takes over:

| | Feature | Detail |
|---|---|---|
| 📊 | **Real-Time Sugar Meter** | Circular progress tracks daily intake vs. WHO 50g/day limit — color shifts green → orange → red |
| 📋 | **Smart Nutrition Form** | Pre-filled with AI prediction. Dynamic fields adapt for beverages (ml) vs. food (g). Auto-calculates total sugar from volume + serving data |
| 🚶 | **Sugar Burn Tracker** | Pedometer integration — sugar meter decreases live as you walk. 1g sugar = 100 steps (1g = 4 kcal, 1 step = 0.04 kcal) |
| 📅 | **Consumption History** | Per-entry cards: time, product name, volume, sugar badge — persisted locally with smart midnight reset |
| 🔍 | **Contextual Search** | One-tap Google search pre-filled with product + variant + volume for manual sugar lookup |

---

## System Architecture

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
│                    SugarProvider   CloudinaryService               │
│                    (local state)   (upload JSON pkg)               │
│                           │                                        │
│                    ActivityController                              │
│                    (pedometer + burn calc)                         │
└──────────────────────────────────────────────────────────────────┘
          │                                    │
          ▼                                    ▼
  SharedPreferences                    Cloudinary Storage
  (daily entries,                      (JSON + Base64 imgs,
   smart reset)                         is_processed: false)
                                               │
                                    ┌──────────▼──────────┐
                                    │   Python Pipeline    │
                                    │   (Google Colab)     │
                                    │                      │
                                    │  Collect → Cluster   │
                                    │  → Train → Export    │
                                    └──────────┬──────────┘
                                               │
                                    ┌──────────▼──────────┐
                                    │   Firebase ML        │
                                    │   Model Downloader   │
                                    │   (OTA .tflite)      │
                                    └──────────┬──────────┘
                                               │
                                    ┌──────────▼──────────┐
                                    │   Flutter App        │
                                    │   auto-downloads     │
                                    │   on next launch     │
                                    └─────────────────────┘
```

### Key Design Decisions

**Cloudinary as the dataset pipeline** — Each scan uploads one JSON package (images + metadata). No backend server needed. The Python script polls for `is_processed: false` entries, processes them, and marks them done. Serverless, cost-free during development.

**Firebase only for model delivery** — OTA model updates without a new app release. The bundled `.tflite` is the offline fallback.

**Provider + ChangeNotifier** — Three reactive streams (sugar entries, step count, burn progress) that need to stay in sync. Provider is the right weight for this — no BLoC overhead.

---

## Monorepo Structure

```
sugar-check-ai/
│
├── lib/
│   ├── controllers/
│   │   ├── camera_controller.dart        # Camera + silent frame capture
│   │   ├── sugar_edit_controller.dart    # Form logic + upload orchestration
│   │   ├── sugar_provider.dart           # Daily entries state + persistence
│   │   └── activity_controller.dart      # Pedometer + sugar burn calculation
│   │
│   ├── models/
│   │   ├── sugar_entry.dart              # id, brandName, totalSugar, volumeTotal, volumeLabel
│   │   └── scan_result.dart
│   │
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── scan_screen.dart
│   │   ├── sugar_edit_screen.dart
│   │   └── main_screen.dart
│   │
│   ├── services/
│   │   ├── tflite_service.dart           # MobileNetV2 inference + confidence threshold
│   │   ├── cloudinary_service.dart       # Compress → Base64 → JSON upload
│   │   └── camera_service.dart
│   │
│   ├── widgets/
│   │   ├── consumption_log_widget.dart   # Horizontal card list (time/product/volume/sugar)
│   │   ├── daily_sugar_card.dart         # Animated circular progress
│   │   ├── step_target_widget.dart       # Steps-to-burn linear progress
│   │   ├── loading_overlay_widget.dart
│   │   └── sugar_edit_widgets.dart       # Category toggle, nutrition form, search button
│   │
│   └── utils/
│       ├── yuv_converter.dart            # YUV420 → RGB for live camera frames
│       └── string_utils.dart
│
├── assets/models/
│   ├── model.tflite                      # Bundled fallback (MobileNetV2, 16 classes)
│   └── labels.txt
│
├── train_model_for_sugar_check_ai/       # Full training pipeline (part of monorepo)
│   ├── notebooks/
│   │   ├── sugar_checker_collector.ipynb
│   │   ├── high_precision_clustering.ipynb
│   │   └── sugar_checker_training.ipynb
│   └── README.md
│
├── android/
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
| Image Processing | `image` + `flutter_image_compress` | YUV→RGB conversion + multi-level compression |
| Dataset Storage | Cloudinary | Serverless pipeline, no backend needed |
| State Management | Provider + ChangeNotifier | Lightweight, reactive, decoupled streams |
| Pedometer | `pedometer` | Real-time step count for burn tracking |
| Local Storage | `shared_preferences` | Daily entries with smart midnight reset |
| Environment | `flutter_dotenv` | Secrets out of source control |

---

## Roadmap

- [x] Custom-trained on-device AI (MobileNetV2, 16 classes, ~93% accuracy)
- [x] Self-improving dataset loop (silent capture → Cloudinary → retrain → OTA)
- [x] Real-time sugar meter with WHO daily limit
- [x] Sugar burn tracker with live pedometer
- [x] Consumption history with per-entry volume
- [ ] **Variant Recognition** — *Indomie Goreng* vs *Indomie Kuah*, *Teh Botol Less Sugar* etc.
- [ ] **Weekly PDF Report** — daily breakdown vs. WHO limits, exportable
- [ ] **Personalized LLM Assistant** — *"Is this safe for me today?"* based on user's intake history

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
```
```env
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_UPLOAD_PRESET=your_unsigned_preset
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

The full pipeline is in [`train_model_for_sugar_check_ai/`](./train_model_for_sugar_check_ai) — 3 Colab notebooks, zero local setup required.

See [`train_model_for_sugar_check_ai/README.md`](./train_model_for_sugar_check_ai/README.md) for the complete guide.

---

## Environment Variables

| Variable | Description |
|---|---|
| `CLOUDINARY_CLOUD_NAME` | Cloud name from Cloudinary Dashboard |
| `CLOUDINARY_UPLOAD_PRESET` | Unsigned upload preset (Settings → Upload) |

> `.env` is gitignored. Use `.env.example` as the template.

---

<div align="center">
Built for Indonesia 🇮🇩 · Flutter + TFLite + Python
</div>
