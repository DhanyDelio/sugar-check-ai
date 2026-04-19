# Sugar Checker — Model Training Pipeline

> Training repository for the [Sugar Check AI](https://github.com/DhanyDelio/sugar-check-ai) mobile app.  
> Produces a `.tflite` model that recognizes Indonesian food & beverage product packaging from camera images.

---

## Project Structure

```
train_model_for_sugar_check_ai/
├── notebooks/
│   ├── sugar_checker_collector.ipynb       # Step 1 — Data collection
│   ├── high_precision_clustering.ipynb     # Step 2 — Image clustering
│   └── sugar_checker_training.ipynb        # Step 3 — Model training & export
└── README.md
```

---

## Full Pipeline Overview

```
OpenFoodFacts Parquet (HuggingFace)
        ↓
[Notebook 1] Filter Indonesia products → Download images
        ↓  + Web crawl (DuckDuckGo + Google)
Raw Dataset (~4,000+ images, unorganized)
        ↓
[Notebook 2] EfficientNetB0 feature extraction
             → Agglomerative Clustering (distance_threshold=0.15)
             → Cosine similarity filter (>0.92)
Clustered Dataset (organized by visual similarity)
        ↓
[Manual Step] Review clusters → rename folders to product class names
              e.g. cluster_039/ → Indomie/
Labeled Dataset (folder = class name)
        ↓
[Notebook 3] Train/Val split → Augmentation → MobileNetV2 fine-tuning
             → Export .tflite + labels.txt
Final Model → copy to Flutter app assets/models/
```

---

## Step-by-Step Guide

### Prerequisites

- Google Account with Google Drive
- Google Colab (free tier works, GPU recommended)
- ~10 GB free space on Google Drive

---

### Step 1 — Data Collection (`sugar_checker_collector.ipynb`)

**What it does:** Downloads product images from OpenFoodFacts and crawls additional images from the web.

**How to run:**
1. Open the notebook in Google Colab
2. Enable GPU: `Runtime → Change runtime type → T4 GPU`
3. Edit `BASE_DIR` in STEP 1 to point to your Google Drive folder
4. Run all cells **in order**

**What each step does:**

| Step | Description |
|------|-------------|
| STEP 0 | Mount Google Drive |
| STEP 1 | Set up folder paths (`images/openfoodfacts/`, `images/crawl/`, `images/unknown/`) |
| STEP 2 | Install dependencies (`requests`, `pandas`, `pyarrow`, `icrawler`, `duckduckgo_search`) |
| STEP 3 | Download `food.parquet` from HuggingFace (~7 GB) — skips if already exists |
| STEP 4 | Filter Indonesia products from 4.4M global entries → extract image URLs → save `indo_products.json` |
| STEP 5 | Download up to 4,000 images from OpenFoodFacts (graded A–E → `openfoodfacts/`, ungraded → `unknown/`) |
| STEP 6 | Web crawl 14 product categories using DuckDuckGo + Google → `images/crawl/` |
| STEP 7 | Print dataset summary |

**Output:**
```
images/
├── openfoodfacts/   # ~330 graded product images
├── crawl/           # ~97+ web-crawled images
└── unknown/         # ~3,670 ungraded images
Total: ~4,097 images
```

**Key config:**
```python
BASE_DIR     = '/content/drive/MyDrive/sugar_checker_data_V2'
MAX_DOWNLOAD = 4000   # max images from OpenFoodFacts
```

> **Note:** DDG crawling may hit rate limits (403). This is normal — Google crawler will still run as fallback.

---

### Step 2 — Image Clustering (`high_precision_clustering.ipynb`)

**What it does:** Groups visually similar images together using deep learning features. This replaces manual sorting.

**How to run:**
1. Zip your collected images into `dataset_for_clustering.zip` and upload to Google Drive
2. Open the notebook in Google Colab (GPU recommended)
3. Edit `ZIP_PATH` and `OUTPUT_DIR` in STEP 2
4. Run all cells **in order**

**What each step does:**

| Step | Description |
|------|-------------|
| STEP 0 | Mount Google Drive |
| STEP 1 | Install dependencies (`tensorflow`, `scikit-learn`, `tqdm`, `pillow`) |
| STEP 2 | Configure paths and clustering parameters |
| STEP 3 | Extract ZIP → auto-detect dataset root → count images |
| STEP 4 | Load EfficientNetB0 (ImageNet pretrained) → extract 1280-dim feature vector per image → L2 normalize |
| STEP 5 | Run Agglomerative Clustering with `distance_threshold=0.15` (strict mode, no fixed n_clusters) |
| STEP 6 | Filter each cluster: compute cosine similarity to centroid → eject images below 0.92 to `cluster_outliers/` |
| STEP 7 | Copy images into `cluster_001/`, `cluster_002/`, ... folders on Drive |
| STEP 8 | Print full clustering report |

**Output:**
```
clustered/
├── cluster_001/    # visually similar group
├── cluster_002/
├── ...
└── cluster_outliers/   # images that didn't fit any cluster
```

**Key config:**
```python
ZIP_PATH           = '/content/drive/MyDrive/dataset_for_clustering.zip'
OUTPUT_DIR         = '/content/drive/MyDrive/sugar_checker_data_V2/images/clustered'
SIMILARITY_THRESH  = 0.92    # lower = more images accepted per cluster
DISTANCE_THRESHOLD = 0.15    # lower = stricter = more clusters
```

**After clustering — manual review required:**
1. Open `clustered/` in Google Drive
2. Browse each `cluster_XXX/` folder
3. If a cluster clearly represents one product, rename the folder to the product name:
   - `cluster_039/` → `Indomie/`
   - `cluster_040/` → `Teh_Botol_Sosro/`
4. Delete clusters that are mixed or irrelevant
5. Zip the labeled folders into `data_for_train.zip`

> Use underscores for multi-word names: `Teh_Botol_Sosro`, `susu_ultramilk`

---

### Step 3 — Model Training (`sugar_checker_training.ipynb`)

**What it does:** Trains a MobileNetV2 classifier on your labeled dataset and exports it as `.tflite` for mobile.

**How to run:**
1. Upload your labeled zip (from Step 2 manual review) to Google Drive
2. Open the notebook in Google Colab — **enable GPU** (required)
3. Edit `ZIP_PATH` and `OUTPUT_DIR` in STEP 2
4. Run all cells **in order**

**What each step does:**

| Step | Description |
|------|-------------|
| STEP 0 | Mount Google Drive |
| STEP 1 | Install & import TensorFlow, scikit-learn, etc. |
| STEP 2 | Configure paths, image size (224×224), batch size, epochs, learning rate |
| STEP 3 | Extract ZIP → deduplicate folders (spaces → underscores) → analyze class distribution |
| STEP 3b | Filter classes with fewer than `MIN_IMAGES=3` images |
| STEP 4 | Manual train/val split (80/20) — handles tiny classes safely |
| STEP 5 | Compute class weights (balanced) — prevents model ignoring small classes |
| STEP 6 | Build augmentation pipeline (rotation, shift, zoom, brightness, flip) |
| STEP 7 | Build model: MobileNetV2 (frozen) + GlobalAveragePooling → Dense(512) → BN → Dropout → Dense(256) → BN → Dropout → Softmax |
| STEP 8 | Train with EarlyStopping, ReduceLROnPlateau, ModelCheckpoint |
| STEP 9 | Evaluate on validation set → print accuracy & classification report |
| STEP 10 | Convert to TFLite (float32) → save `model.tflite` + `labels.txt` to Drive |

**Key config:**
```python
ZIP_PATH      = '/content/drive/My Drive/sugar_checker_data_V2/reviewed_clustered/data_for_train_phase_3.zip'
OUTPUT_DIR    = '/content/drive/My Drive/sugar_checker_data_V2/model_output'

IMG_SIZE      = (224, 224)
BATCH_SIZE    = 16
EPOCHS        = 100        # EarlyStopping will cut short
LEARNING_RATE = 1e-4
VAL_SPLIT     = 0.2
```

**Output:**
```
model_output/
├── model.tflite     # final model for mobile
├── labels.txt       # class names, one per line
└── labels.json      # class index → name mapping
```

**Model architecture:**
```
Input (224×224×3)
  → MobileNetV2 backbone (frozen, ImageNet weights)
  → GlobalAveragePooling2D → (1280,)
  → Dense(512) + BatchNorm + Dropout(0.5)
  → Dense(256) + BatchNorm + Dropout(0.5)
  → Dense(N_CLASSES, softmax)
```

**Achieved performance (Phase 3, 16 classes, 250 images):**
- Val Accuracy: ~93%
- Export: float32 TFLite

---

### Step 4 — Deploy to Flutter App

1. Copy `model.tflite` → `assets/models/model.tflite` in the Flutter project
2. Copy `labels.txt` → `assets/models/labels.txt`
3. The app's `TFLiteService` will load and run inference automatically

---

## Tips & Troubleshooting

| Issue | Fix |
|-------|-----|
| DDG crawl returns 403 | Normal rate limit — wait a few minutes or skip, Google crawler is the fallback |
| Parquet download fails | Check Drive space (needs ~7 GB free) — the notebook auto-retries 3 times |
| Low val accuracy | Add more images per class (aim for 20+), or lower `DISTANCE_THRESHOLD` in clustering for purer clusters |
| Model overfits | Increase `Dropout`, reduce `LEARNING_RATE`, or add more augmentation |
| TFLite inference wrong | Make sure `labels.txt` order matches the training class order in `labels.json` |
| Colab disconnects mid-training | Use `ModelCheckpoint` — training auto-saves best weights, re-run from STEP 8 |

---

## Requirements

```
tensorflow >= 2.x
scikit-learn
pandas
pyarrow
requests
icrawler
duckduckgo_search
pillow
tqdm
numpy
```

Install all at once:
```bash
pip install tensorflow scikit-learn pandas pyarrow requests icrawler duckduckgo_search pillow tqdm numpy
```

---

## Related

- **Mobile App:** [Sugar Check AI](https://github.com/DhanyDelio/sugar-check-ai)
- **Dataset Source:** [OpenFoodFacts on HuggingFace](https://huggingface.co/datasets/openfoodfacts/product-database)
