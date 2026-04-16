# Doctor Gula — AI-Powered Sugar Intake Tracker

A Flutter mobile app that helps users monitor their daily sugar intake using AI. Simply point the camera at a product's packaging, and the app will automatically detect the product and calculate its total sugar content.

---

## Features

- **AI Product Detection** — TFLite (MobileNetV2) model to recognize products from packaging photos
- **Sugar Tracking** — Real-time daily sugar calculation with WHO limit indicator (50g/day)
- **Smart Form** — Dynamic nutrition form supporting both beverages and food products
- **Dataset Collection** — Silent background capture + Cloudinary upload for continuous model improvement
- **Google AI Search** — Quick shortcut to search sugar content via Google

### Roadmap
- **Activity Gamification** — Every sugar entry will trigger an activity suggestion: *"Walk for 12 minutes to burn this 10g of sugar"*. Step progress reduces the meter total in real-time using the device accelerometer.
- **Weekly Report** — Download a weekly PDF report containing consumed products, daily sugar intake, and a weekly summary compared to the WHO recommended limit.
- **Personalized LLM Assistant** — A fine-tuned language model trained on nutrition and diabetes data to provide personalized sugar limit recommendations based on the user's health profile. Diabetic users will be able to consult the AI directly — asking questions like *"Is this product safe for me today?"* or *"How much sugar can I still consume this evening?"* — making the app a proactive health companion, not just a passive tracker.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| AI Inference | TFLite Flutter + Firebase ML Model Downloader |
| Image Processing | `image` package + `flutter_image_compress` |
| Cloud Storage | Cloudinary (unsigned upload) |
| State Management | Provider + ChangeNotifier |
| Navigation | Global NavigationService |

---

## Architecture

```
lib/
├── controllers/        Business logic (camera, form, state)
├── core/navigation/    Global navigation service
├── models/             Type-safe data models
├── screens/            UI screens
├── services/           External integrations (TFLite, Cloudinary)
├── utils/              Helper functions (image, string)
└── widgets/            Reusable UI components
```

---

## Setup

### 1. Clone & install dependencies
```bash
git clone <repo-url>
cd sugarcheck
flutter pub get
```

### 2. Configure environment
```bash
cp .env.example .env
```
Fill in your Cloudinary credentials:
```
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_UPLOAD_PRESET=your_unsigned_preset
```

### 3. Firebase
- Add `google-services.json` to `android/app/`
- Make sure Firebase ML Model Downloader is configured in your Firebase project

### 4. Run
```bash
flutter run
```

---

## Dataset Pipeline

Every time a user scans and confirms nutrition data, the app automatically:
1. Compresses the primary photo (800px, quality 45) + 9 silent background frames (400px, quality 30)
2. Encodes all images to Base64
3. Uploads a single JSON package to Cloudinary with `is_processed: false`

An external Python script can then pull this data to retrain the AI model.

---

## Environment Variables

| Variable | Description |
|---|---|
| `CLOUDINARY_CLOUD_NAME` | Cloud name from Cloudinary Dashboard |
| `CLOUDINARY_UPLOAD_PRESET` | Unsigned upload preset (Settings → Upload) |

> `.env` is listed in `.gitignore` — never commit this file.
