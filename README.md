<div align="center">

# 🩺 Doctor Gula

### Indonesia has 19 million diabetics. Most don't track sugar because it's too hard. This app uses a custom-trained on-device AI to make it instant — point camera, get sugar content, no typing.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![TensorFlow Lite](https://img.shields.io/badge/TFLite-MobileNetV2-FF6F00?logo=tensorflow)](https://www.tensorflow.org/lite)
[![AWS Amplify](https://img.shields.io/badge/AWS-Amplify%20%2B%20S3-FF9900?logo=amazonaws)](https://aws.amazon.com/amplify/)
[![Go Lambda](https://img.shields.io/badge/Go-Lambda-00ADD8?logo=go)](https://go.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://android.com)

https://github.com/user-attachments/assets/10cc03a7-1fa4-47e6-bf1a-441dbad71873

</div>

---

## 😤 The Problem: Manual Lookup Sucks

Coba bayangin kamu mau ngecek kadar gula di Teh Botol yang baru kamu beli. Kamu harus:

1. Buka app
2. Ketik nama produk
3. Scroll nyari yang cocok
4. Baca angkanya
5. Hitung sendiri berapa yang udah kamu minum hari ini

**Nobody does this.** Terlalu ribet, terlalu lambat, terlalu gampang di-skip.

Solusinya cuma satu: **Point & Shoot.** Arahkan kamera ke kemasan → AI kenali produknya → kadar gula langsung masuk ke meter. Zero typing, zero searching, zero friction.

Tapi untuk bikin ini jalan di produk Indonesia, gue harus bangun dataset-nya dari nol — karena tidak ada model yang sudah ada untuk produk lokal.

---

## 🤖 Building the AI From Scratch

```
Problem: no labeled dataset for Indonesian packaged goods
        │
        ▼
Downloaded 4.4M product records from OpenFoodFacts (HuggingFace)
Filtered: ~7,953 Indonesia-specific entries
Downloaded: 4,000+ product images + web-crawled 14 categories
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
        │
        ▼
~93% validation accuracy → export .tflite → on-device
```

Full pipeline (3 Colab notebooks) ada di [`train_model_for_sugar_check_ai/`](./train_model_for_sugar_check_ai).

---

## 🏗️ Architecture

```
📱 Flutter App
    │
    ├─ 📸 CameraController ──► 🧠 TFLiteService (on-device inference)
    │         │                        │
    │   Silent Frames (9x)      Inference Result
    │         │                        │
    └─────────┴──────────► 📝 SugarEditScreen
                                  │
                           SugarEditController
                            │            │
                     SugarProvider   AwsStorageService
                     (sugar meter)   (presign request)
                            │
                     ActivityController
                     (step credit system)
                                  │
                                  ▼
                    🔐 API Gateway (POST /upload)
                                  │
                    ⚡ Go Lambda (SugarCheckBackend)
                    ├── Rate limit check (DynamoDB)
                    ├── Content-type whitelist
                    ├── File size enforcement (200KB/5KB)
                    └── Generate presigned S3 PUT URL (5 min)
                                  │
                    📦 AWS S3: public/quarantine-dataset/
                    [product]/[variant]/[volume]/
                                  │
                         Manual Annotation 👀
                                  │
                    ✅ public/dataset/ (verified)
                                  │
                    🤗 Hugging Face (train → ONNX)
                                  │
                    ☁️ AWS Inference (ONNX Runtime)
```

---

## 🔒 Data Integrity: Quarantine-First Strategy

Ini salah satu keputusan arsitektur yang paling penting di project ini.

**Masalahnya:** User input tidak selalu akurat. Nama produk bisa salah ketik, foto bisa blur, atau data nutrisi bisa tidak sesuai label. Kalau data sampah langsung masuk ke training, model bakal "keracunan" — *Garbage In, Garbage Out*.

**Solusinya: Quarantine Dataset**

```
User upload foto
        │
        ▼
🔴 public/quarantine-dataset/   ← semua upload masuk sini dulu
        │
        ▼ manual review & annotation
        │
🟢 public/dataset/              ← hanya data yang sudah verified
        │
        ▼
Training pipeline
```

Tidak ada satu pun data yang masuk ke training tanpa melewati review manual. Model yang dihasilkan lebih akurat karena dilatih dengan data yang bersih.

---

## 🛡️ Upload Security

Setiap upload dari app melewati Go Lambda sebelum menyentuh S3:

| Check | Detail |
|---|---|
| **Rate Limiting** | Max 30 upload/menit per device UUID (DynamoDB atomic counter) |
| **Content-Type Whitelist** | Hanya `image/jpeg` dan `application/json` |
| **File Size Enforcement** | Max 200KB untuk image, 5KB untuk JSON sidecar |
| **Presigned URL** | Expire dalam 5 menit — Flutter tidak punya akses S3 langsung |
| **Staging Folder** | Hardcoded server-side — client tidak bisa override ke `dataset/` |

Go dipilih untuk Lambda karena **cold start yang sangat cepat** (~10ms vs ~500ms untuk Node.js/Python) — penting untuk latency upload yang smooth.

---

## 📊 Model Specs

| Property | Value |
|---|---|
| Architecture | MobileNetV2 (frozen) + Dense(512) + Dense(256) + Softmax |
| Input | 224 × 224 × 3, normalized to `[-1, 1]` |
| Output | Softmax over 16 Indonesian product classes |
| Confidence threshold | 50% — below this, field is left blank |
| Val accuracy | ~93% (Phase 3, 250 labeled images) |
| Deployment | On-device TFLite (current) → AWS ONNX (roadmap) |

**Recognized brands (v1 — 16 classes):**

`Adem Sari` · `Dum Dum` · `Frisian Flag` · `Hatari` · `Indomaret` · `Indomie` · `Indomilk` · `Interbis` · `Nola` · `Oatside` · `Oreo` · `Teh Botol Sosro` · `Cokelat Cadbury` · `Cokelat Delfi` · `Cokelat SilverQueen` · `Susu Ultra Milk`

---

## ✨ What the App Does

| | Feature | Detail |
|---|---|---|
| 📊 | **Real-Time Sugar Meter** | Circular progress vs WHO 50g/day limit — green → orange → red |
| 📋 | **Smart Nutrition Form** | Pre-filled from AI. Adapts for beverages (ml) vs food (g) |
| 🚶 | **Activity Offset** | Steps → hidden sugar credit (1,000 steps = 1g, max 15g/day) |
| 📅 | **Consumption History** | Per-entry cards: time, product, volume, raw label sugar |
| 🔍 | **Contextual Search** | One-tap Google search pre-filled with product + variant + volume |

---

## 🧰 Tech Stack

| Layer | Technology | Why |
|---|---|---|
| Framework | Flutter 3 (Dart) | Single codebase, 60fps UI |
| AI Inference (now) | TFLite Flutter | On-device, zero latency, offline |
| AI Inference (roadmap) | AWS ONNX Runtime | Server-side, update without app release |
| Upload Gateway | **Go Lambda** + API Gateway | Fast cold start (~10ms), rate limiting, presigned URLs |
| Dataset Storage | AWS S3 | Physical clustering via path structure |
| Rate Limiting | **DynamoDB** | Atomic counter, auto-expire TTL |
| Auth | AWS Cognito (Amplify) | Anonymous device identity, no login needed |
| Image Processing | `image` + `flutter_image_compress` | YUV→RGB + parallel compression |
| State Management | Provider + ChangeNotifier | Lightweight, reactive |
| Pedometer | `pedometer` + `flutter_foreground_task` | Background step counting, Realme/OPPO compatible |
| Local Storage | `shared_preferences` | Daily entries + step credit + device UUID |

---

## 🗺️ Roadmap

- [x] Custom-trained on-device AI (MobileNetV2, 16 classes, ~93% accuracy)
- [x] Secure upload pipeline (Go Lambda + API Gateway + presigned S3 URLs)
- [x] Quarantine-first data strategy (manual annotation before training)
- [x] Rate limiting per device UUID (DynamoDB, 30 uploads/min)
- [x] Real-time sugar meter with WHO daily limit
- [x] Activity offset — hidden credit system (1,000 steps = 1g, 15g/day cap)
- [x] Background step counting (foreground service, Realme/OPPO compatible)
- [x] Anonymous device UUID — no login required
- [ ] 🔄 **ONNX Migration** — move from on-device TFLite to AWS server-side inference
- [ ] 🏷️ **Variant Recognition** — bedain *Teh Pucuk* vs *Fruit Tea*, *Indomie Goreng* vs *Indomie Kuah*
- [ ] 📄 **Weekly PDF Report** — ringkasan mingguan konsumsi gula vs WHO limit
- [ ] 🤖 **LLM Assistant** — *"Hari ini aman minum ini ga?"* berdasarkan history intake

---

## 🚀 Setup

### 1. Clone & install
```bash
git clone https://github.com/DhanyDelio/sugar-check-ai.git
cd sugar-check-ai
flutter pub get
```

### 2. AWS Amplify
```bash
npm install -g @aws-amplify/cli
amplify pull
# Generates lib/amplifyconfiguration.dart (gitignored)
```

### 3. Environment
```bash
cp .env.example .env
# Add your API Gateway URL
```

### 4. Firebase
- Add `google-services.json` to `android/app/`
- Enable ML Kit + ML Model Downloader in Firebase Console

### 5. Run
```bash
flutter run
```

---

## 🧠 Training the Model

Full pipeline di [`train_model_for_sugar_check_ai/`](./train_model_for_sugar_check_ai) — 3 Colab notebooks, zero local setup.

---

<div align="center">
Built for Indonesia 🇮🇩 · Flutter + Go + AWS + TFLite
</div>
