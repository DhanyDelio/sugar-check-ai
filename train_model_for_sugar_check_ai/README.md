<div align="center">

# 🧠 Sugar Checker — Model Training Pipeline

**End-to-end pipeline for training a MobileNetV2 image classifier on Indonesian food & beverage packaging.**  
Produces a `.tflite` model deployed directly into the [Doctor Gula](https://github.com/DhanyDelio/sugar-check-ai) mobile app.

[![Python](https://img.shields.io/badge/Python-3.8+-3776AB?logo=python)](https://python.org)
[![TensorFlow](https://img.shields.io/badge/TensorFlow-2.x-FF6F00?logo=tensorflow)](https://tensorflow.org)
[![Google Colab](https://img.shields.io/badge/Run%20on-Google%20Colab-F9AB00?logo=googlecolab)](https://colab.research.google.com)
[![Dataset](https://img.shields.io/badge/Dataset-OpenFoodFacts-green)](https://huggingface.co/datasets/openfoodfacts/product-database)

</div>

---

## Data Engineering & Training Strategy

Training a reliable product recognition model for Indonesian local goods is not a straightforward task. This section documents the key engineering decisions made during the data pipeline design — decisions driven by real constraints encountered during development.

### The Problem: Data Scarcity & Overfitting

The initial approach was to train at a granular level — classifying by **Brand + Variant** (e.g. *Indomie Goreng* vs *Indomie Kuah*). This failed immediately.

Most variants had only 1–2 reference photos. Training on such a sparse set — even with aggressive class weighting and augmentation — produces a model that **memorizes specific images** rather than learning generalizable visual features. The result is near-perfect training accuracy and catastrophic validation failure. This is textbook overfitting, and no amount of regularization fixes a fundamentally insufficient dataset.

**Decision:** Scope the model down to **Brand-level classification** only. Fewer classes, more samples per class, stable training.

### Data Integrity Issues with Open Food Facts

Open Food Facts is a valuable public dataset, but it has a critical limitation for local markets: **metadata accuracy is not guaranteed**. For Indonesian products specifically:

- Sugar content values are often missing, incorrect, or entered in inconsistent units
- Product names are frequently in English or mixed-language, not matching local packaging
- Many entries have placeholder images or images of the wrong product variant

Training on unverified data directly would produce a "Garbage In, Garbage Out" model — one that confidently predicts wrong answers. To prevent this, **every entry used for training was manually verified and annotated**. This is expensive in time but non-negotiable for a health-adjacent application.

### The Solution: Hybrid Manual-AI Curation

Rather than fully manual or fully automated labeling, a hybrid approach was used:

```
Raw images (OpenFoodFacts + web crawl)
        │
        ▼
EfficientNetB0 feature extraction
→ Agglomerative Clustering (distance_threshold=0.15)
→ Cosine similarity filter (>0.92)
        │
        ▼  ← AI does the heavy lifting here
Cluster folders (cluster_001/, cluster_002/, ...)
        │
        ▼  ← Human takes over here
Manual review: verify each cluster visually
→ Rename valid clusters to product class names
→ Discard mixed or low-quality clusters
        │
        ▼
"Gold Dataset" — clean, verified, ready for training
```

EfficientNetB0 handles the scale problem (sorting thousands of images by visual similarity). The human step ensures label correctness. Neither alone is sufficient — the combination produces a dataset that is both large enough to train on and accurate enough to trust.

### Future-Proofing: User-Driven Incremental Retraining

The current model is intentionally scoped to what the data can support today. The architecture is designed to get more granular over time through real-world usage:

```
Phase 1 (Now)
  Model: Brand-level classifier (16 classes, ~93% val accuracy)
  Data source: Curated Gold Dataset

Phase 2 (In Progress)
  Every confirmed user scan uploads:
    - Primary photo + 9 silent background frames
    - User-verified product name, variant, volume, sugar content
  This real-world data is richer and more accurate than any public dataset
  because it comes from actual product packaging in actual lighting conditions.

Phase 3 (Future)
  Retrain on accumulated user data
  → Brand + Variant classification
  → Volume-aware sugar calculation
  → Continuous improvement loop
```

The key insight: **forcing a granular model with insufficient data produces a worse outcome than a simpler model trained on clean data**. The system is designed to be correct today and more capable tomorrow — not the other way around.

---

## Pipeline Overview

```
OpenFoodFacts Parquet (4.4M products, HuggingFace)
        │
        ▼
┌─────────────────────────────────────────────────────┐
│  NOTEBOOK 1 — sugar_checker_collector.ipynb          │
│                                                       │
│  Filter: Indonesia products only (~7,953)             │
│  Download: up to 4,000 images from OpenFoodFacts      │
│  Crawl: 14 categories via DuckDuckGo + Google         │
│                                                       │
│  Output: ~4,097 raw, unorganized images               │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│  NOTEBOOK 2 — high_precision_clustering.ipynb        │
│                                                       │
│  EfficientNetB0 → 1280-dim feature vectors           │
│  L2 Normalize → Agglomerative Clustering             │
│  Cosine similarity filter (>0.92 per cluster)        │
│                                                       │
│  Output: cluster_001/ cluster_002/ ... (organized)   │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
              ┌─────────────────┐
              │  MANUAL REVIEW  │
              │                 │
              │  Rename folders │
              │  cluster_039/   │
              │    → Indomie/   │
              └────────┬────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│  NOTEBOOK 3 — sugar_checker_training.ipynb           │
│                                                       │
│  Train/Val split (80/20, handles tiny classes)        │
│  Class weight balancing                               │
│  Aggressive augmentation                              │
│  MobileNetV2 fine-tuning (frozen backbone)           │
│  EarlyStopping + ReduceLROnPlateau                   │
│                                                       │
│  Output: model.tflite + labels.txt                   │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
        Copy to Flutter: assets/models/
```

---

## Project Structure

```
train_model_for_sugar_check_ai/
├── notebooks/
│   ├── sugar_checker_collector.ipynb       # Step 1 — data collection
│   ├── high_precision_clustering.ipynb     # Step 2 — image clustering
│   └── sugar_checker_training.ipynb        # Step 3 — train & export
└── README.md
```

---

## Prerequisites

- Google Account + Google Drive (~10 GB free space)
- Google Colab (free tier works; **T4 GPU strongly recommended** for Steps 2 & 3)
- No local Python setup required — everything runs in Colab

---

## Step 1 — Data Collection

**Notebook:** `sugar_checker_collector.ipynb`

Downloads product images from OpenFoodFacts and supplements with web-crawled images.

### How to run
1. Open in Google Colab
2. Edit `BASE_DIR` in **STEP 1** to your Google Drive path
3. Run all cells in order — **do not skip**

### What each cell does

| Cell | Action |
|------|--------|
| STEP 0 | Mount Google Drive |
| STEP 1 | Create output folders: `images/openfoodfacts/`, `images/crawl/`, `images/unknown/` |
| STEP 2 | Install: `requests pandas pyarrow icrawler duckduckgo_search` |
| STEP 3 | Download `food.parquet` from HuggingFace (~7 GB) — auto-skips if valid file exists, auto-retries on corruption |
| STEP 4 | Read parquet (selected columns only) → filter `countries_tags` for Indonesia → extract image URLs → save `indo_products.json` |
| STEP 5 | Download up to `MAX_DOWNLOAD=4000` images. Graded (A–E) → `openfoodfacts/`. Ungraded → `unknown/` |
| STEP 6 | Web crawl 14 Indonesian product categories via DuckDuckGo + Google Image Crawler |
| STEP 7 | Print dataset summary |

### Configuration
```python
BASE_DIR     = '/content/drive/MyDrive/sugar_checker_data_V2'
MAX_DOWNLOAD = 4000   # max images from OpenFoodFacts
```

### Output
```
images/
├── openfoodfacts/   # ~330 graded product images (Nutriscore A–E)
├── crawl/           # ~97+ web-crawled images
└── unknown/         # ~3,670 ungraded images
                     # Total: ~4,097 images
```

> **DDG rate limit (403):** Normal behavior. The notebook continues with Google Image Crawler as fallback. No action needed.

---

## Step 2 — Image Clustering

**Notebook:** `high_precision_clustering.ipynb`

Groups visually similar images using deep learning features — replacing hours of manual sorting.

### How to run
1. Zip all collected images → upload to Google Drive as `dataset_for_clustering.zip`
2. Open in Google Colab (GPU recommended)
3. Edit `ZIP_PATH` and `OUTPUT_DIR` in **STEP 2**
4. Run all cells in order

### What each cell does

| Cell | Action |
|------|--------|
| STEP 0 | Mount Google Drive |
| STEP 1 | Install: `tensorflow scikit-learn tqdm numpy pillow` |
| STEP 2 | Configure paths + clustering parameters |
| STEP 3 | Extract ZIP → auto-detect dataset root → count valid images |
| STEP 4 | Load **EfficientNetB0** (ImageNet pretrained, no top) → `GlobalAveragePooling2D` → 1280-dim feature vector per image → **L2 normalize** |
| STEP 5 | **Agglomerative Clustering** with `distance_threshold=0.15`, `metric='cosine'`, `linkage='average'` — no fixed `n_clusters`, algorithm decides |
| STEP 6 | For each cluster: compute cosine similarity of every image to cluster centroid → eject images below `SIMILARITY_THRESH=0.92` to `cluster_outliers/` |
| STEP 7 | Copy accepted images into `cluster_001/`, `cluster_002/`, ... on Drive |
| STEP 8 | Print full clustering report |

### Configuration
```python
ZIP_PATH           = '/content/drive/MyDrive/dataset_for_clustering.zip'
OUTPUT_DIR         = '/content/drive/MyDrive/sugar_checker_data_V2/images/clustered'
SIMILARITY_THRESH  = 0.92    # cosine similarity floor — lower = more images per cluster
DISTANCE_THRESHOLD = 0.15    # agglomerative threshold — lower = stricter = more clusters
```

### Output
```
clustered/
├── cluster_001/         # visually coherent group
├── cluster_002/
├── ...
└── cluster_outliers/    # images that didn't meet similarity threshold
```

### Manual review (required after clustering)

The clustering is unsupervised — you need to label the clusters:

1. Open `clustered/` in Google Drive
2. Browse each `cluster_XXX/` folder — most will clearly show one product
3. Rename the folder to the product name:
   ```
   cluster_039/  →  Indomie/
   cluster_040/  →  Teh_Botol_Sosro/
   cluster_097/  →  Oreo/
   ```
4. Delete clusters that are mixed, irrelevant, or too small (< 3 images)
5. Zip the labeled folders → `data_for_train.zip`

> **Naming convention:** Use underscores for multi-word names — `Teh_Botol_Sosro`, `susu_ultramilk`, `cokelat_cadburry`. The folder name becomes the class label.

---

## Step 3 — Model Training

**Notebook:** `sugar_checker_training.ipynb`

Trains a MobileNetV2 classifier and exports it as `.tflite` for mobile deployment.

### How to run
1. Upload your labeled zip to Google Drive
2. Open in Google Colab — **enable GPU** (`Runtime → Change runtime type → T4 GPU`)
3. Edit `ZIP_PATH` and `OUTPUT_DIR` in **STEP 2**
4. Run all cells in order

### What each cell does

| Cell | Action |
|------|--------|
| STEP 0 | Mount Google Drive |
| STEP 1 | Import TensorFlow, scikit-learn, Keras callbacks |
| STEP 2 | Configure all paths and hyperparameters |
| STEP 3 | Extract ZIP → deduplicate folders (spaces → underscores, merge duplicates) → analyze class distribution with bar chart |
| STEP 3b | Filter classes with fewer than `MIN_IMAGES=3` — prevents training on single-image classes |
| STEP 4 | Manual 80/20 train/val split — handles tiny classes safely (1-image classes duplicated to both splits) |
| STEP 5 | Compute **balanced class weights** via `sklearn.utils.class_weight` — prevents model ignoring minority classes |
| STEP 6 | Build augmentation pipeline: rotation ±40°, shift ±30%, zoom ±30%, brightness [0.5–1.5], horizontal flip |
| STEP 7 | Build model: MobileNetV2 (frozen) → GAP → Dense(512)+BN+Dropout(0.5) → Dense(256)+BN+Dropout(0.5) → Softmax |
| STEP 8 | Train with `EarlyStopping(patience=15)`, `ReduceLROnPlateau(factor=0.5)`, `ModelCheckpoint(save_best_only=True)` |
| STEP 9 | Evaluate on val set → print accuracy + per-class classification report |
| STEP 10 | Convert to **TFLite float32** → save `model.tflite` + `labels.txt` + `labels.json` to Drive |

### Configuration
```python
ZIP_PATH      = '/content/drive/My Drive/.../data_for_train.zip'
OUTPUT_DIR    = '/content/drive/My Drive/.../model_output'

IMG_SIZE      = (224, 224)
BATCH_SIZE    = 16        # small batch for small dataset
EPOCHS        = 100       # EarlyStopping cuts this short
LEARNING_RATE = 1e-4
VAL_SPLIT     = 0.2
MIN_IMAGES    = 3         # minimum images per class
```

### Model Architecture
```
Input: (224, 224, 3)
  │
  ▼
MobileNetV2 backbone — frozen (ImageNet weights)
  │  2,257,984 params (not trained)
  ▼
GlobalAveragePooling2D → (1280,)
  ▼
Dense(512) + BatchNormalization + Dropout(0.5)
  ▼
Dense(256) + BatchNormalization + Dropout(0.5)
  ▼
Dense(N_CLASSES, activation='softmax')

Total trainable params: ~794,000
```

### Results (Phase 3)

| Metric | Value |
|--------|-------|
| Classes | 16 Indonesian product brands |
| Training images | 207 |
| Validation images | 43 |
| Val accuracy | **~93%** |
| Export format | TFLite float32 |

### Output
```
model_output/
├── model.tflite     # deploy to Flutter assets/models/
├── labels.txt       # one class name per line (index-ordered)
└── labels.json      # { "0": "Adem_Sari", "1": "Dum_Dum", ... }
```

---

## Step 4 — Deploy to Flutter

```bash
# From the model_output/ folder on your machine:
cp model.tflite  ../assets/models/model.tflite
cp labels.txt    ../assets/models/labels.txt
```

The app's `TFLiteService` loads both files at startup. The bundled model serves as the offline fallback — Firebase ML Model Downloader will replace it with the latest version on first launch.

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| DDG crawl returns 403 | Rate limit | Normal — Google crawler runs as fallback, no action needed |
| Parquet download fails | Drive space / network | Needs ~7 GB free. Notebook auto-retries 3× with corruption check |
| Low val accuracy | Too few images per class | Aim for 20+ images per class. Lower `DISTANCE_THRESHOLD` for purer clusters |
| Model overfits (train >> val) | Small dataset | Increase `Dropout`, reduce `LEARNING_RATE`, add more augmentation |
| TFLite gives wrong labels | Label order mismatch | Verify `labels.txt` index order matches `labels.json` from training |
| Colab disconnects mid-training | Session timeout | `ModelCheckpoint` saves best weights — re-run from STEP 8 to resume |
| Folder merge errors on extract | macOS `.DS_Store` / spaces | STEP 3 auto-handles this — merges `"Teh Botol Sosro"` → `Teh_Botol_Sosro` |

---

## Requirements

```bash
pip install tensorflow scikit-learn pandas pyarrow \
            requests icrawler duckduckgo_search \
            pillow tqdm numpy
```

> All notebooks install dependencies automatically in their STEP 1/2 cells. No local setup required if running on Google Colab.

---

## Related

- **Mobile App:** [Doctor Gula — Sugar Check AI](https://github.com/DhanyDelio/sugar-check-ai)
- **Dataset Source:** [OpenFoodFacts on HuggingFace](https://huggingface.co/datasets/openfoodfacts/product-database)
- **Base Model:** [MobileNetV2 — TensorFlow](https://www.tensorflow.org/api_docs/python/tf/keras/applications/MobileNetV2)
- **Feature Extractor:** [EfficientNetB0 — TensorFlow](https://www.tensorflow.org/api_docs/python/tf/keras/applications/EfficientNetB0)
