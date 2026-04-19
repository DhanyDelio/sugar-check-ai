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
