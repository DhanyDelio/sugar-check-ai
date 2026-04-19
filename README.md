<div align="center">

# 🩺 Doctor Gula

### A mobile app that uses a custom-trained on-device AI model to identify Indonesian packaged food products from a camera photo — then automatically calculates sugar content and tracks daily intake against WHO limits.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![TensorFlow Lite](https://img.shields.io/badge/TFLite-MobileNetV2-FF6F00?logo=tensorflow)](https://www.tensorflow.org/lite)
[![Cloudinary](https://img.shields.io/badge/Cloudinary-Dataset%20Pipeline-3448C5)](https://cloudinary.com)
[![Firebase](https://img.shields.io/badge/Firebase-ML%20Delivery-FFCA28?logo=firebase)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://android.com)

</div>

---

## Why This Exists

Indonesia ranks top 10 globally for diabetes prevalence. The core problem isn't awareness — it's friction. People don't track sugar because existing apps require manual lookup, have no intelligence, and aren't built for Indonesian products.

The solution had to be **zero-friction**: point camera → get answer. No typing, no searching, no guessing.

That required building the AI from scratch — there was no existing model for Indonesian packaged goods.

---

## The AI Is the Product

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
