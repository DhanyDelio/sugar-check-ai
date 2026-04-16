# Sugar Checker - Indonesian Food Product Classification

A machine learning project for classifying Indonesian food and beverage products using computer vision, with a focus on nutritional grading and product recognition.

> **Note:** This is the model training repository for the [Sugar Check AI](https://github.com/DhanyDelio/sugar-check-ai) mobile application.

## 📋 Project Overview

This project consists of three main components:

1. **Data Collection Pipeline** - Automated image collection from OpenFoodFacts and web crawling
2. **High-Precision Clustering** - Image clustering using EfficientNetB0 for dataset organization
3. **Model Training** - MobileNetV2-based classification model for product recognition

## 🚀 Features

- Automated data collection from OpenFoodFacts database (Indonesia products)
- Web crawling for additional product images (DuckDuckGo + Google)
- High-precision image clustering with cosine similarity filtering
- MobileNetV2 model training with aggressive augmentation
- TensorFlow Lite export for mobile deployment
- Support for 16+ product categories

## 📁 Project Structure

```
.
├── notebooks/
│   ├── sugar_checker_collector.ipynb          # Data collection
│   ├── high_precision_clustering.ipynb        # Image clustering
│   └── sugar_checker_training.ipynb           # Model training
├── README.md
└── .gitignore
```

## 🛠️ Installation

### Requirements

- Python 3.8+
- TensorFlow 2.x
- Google Colab (recommended for GPU access)

### Dependencies

```bash
pip install tensorflow scikit-learn pandas pyarrow
pip install requests icrawler duckduckgo_search
pip install pillow tqdm numpy
```

## 📊 Pipeline Workflow

### 1. Data Collection

```
OpenFoodFacts Parquet → Filter Indonesia Products → Download Images
                                                   ↓
                                          Web Crawling (DDG + Google)
                                                   ↓
                                          Organized Dataset
```

**Features:**
- Filters products by country (Indonesia)
- Separates graded (A-E) and ungraded products
- Downloads up to 4,000 images from OpenFoodFacts
- Crawls additional images for 14 product categories

### 2. High-Precision Clustering

```
Dataset → EfficientNetB0 Feature Extraction → L2 Normalization
                                             ↓
                              Agglomerative Clustering (distance_threshold=0.15)
                                             ↓
                              Cosine Similarity Filter (>0.92)
                                             ↓
                              Organized Clusters
```

**Features:**
- Uses EfficientNetB0 (ImageNet pretrained) for feature extraction
- Strict clustering with configurable distance threshold
- Cosine similarity filtering to ensure cluster purity
- Automatic outlier detection and separation

### 3. Model Training

```
Clustered Dataset → Train/Val Split → Augmentation
                                    ↓
                         MobileNetV2 Fine-tuning
                                    ↓
                         TFLite Export (float32)
```

**Features:**
- MobileNetV2 backbone (frozen)
- Custom classification head with dropout
- Class weight balancing for imbalanced datasets
- Aggressive augmentation (rotation, shift, zoom, brightness)
- Early stopping and learning rate reduction
- TensorFlow Lite export for mobile deployment

## 🎯 Model Performance

- **Architecture:** MobileNetV2 + Custom Head
- **Input Size:** 224x224x3
- **Classes:** 16 Indonesian product brands
- **Best Val Accuracy:** 93% (phase 3 training)
- **Export Format:** TFLite (float32)

## 📝 Usage

### 1. Collect Data

Open `notebooks/sugar_checker_collector.ipynb` in Google Colab and run all cells sequentially.

**Configuration:**
```python
ZIP_PATH = '/content/drive/MyDrive/sugar_checker_data_V2/food.parquet'
MAX_DOWNLOAD = 4000  # Max images from OpenFoodFacts
```

### 2. Cluster Images

Open `notebooks/high_precision_clustering.ipynb` and run all cells.

**Configuration:**
```python
SIMILARITY_THRESH = 0.92   # Cosine similarity threshold
DISTANCE_THRESHOLD = 0.15  # Agglomerative clustering threshold
```

### 3. Train Model

Open `notebooks/sugar_checker_training.ipynb` and run all cells.

**Configuration:**
```python
IMG_SIZE = (224, 224)
BATCH_SIZE = 16
EPOCHS = 100
LEARNING_RATE = 1e-4
```

## 📦 Dataset

The dataset includes images from:
- **OpenFoodFacts:** Official product images with nutritional grades
- **Web Crawling:** Additional product images from search engines

**Product Categories:**
- Instant noodles (Indomie)
- Milk products (Indomilk, Frisian Flag, Ultra Milk)
- Chocolate (Cadbury, Delfi, SilverQueen)
- Biscuits (Oreo, Hatari, Interbis)
- Beverages (Teh Botol Sosro, Oatside)
- And more...

## 🔧 Configuration

### Clustering Parameters

- `SIMILARITY_THRESH`: Minimum cosine similarity for cluster membership (default: 0.92)
- `DISTANCE_THRESHOLD`: Agglomerative clustering threshold (default: 0.15)
- Lower values = stricter clustering = more clusters

### Training Parameters

- `IMG_SIZE`: Input image size (default: 224x224)
- `BATCH_SIZE`: Training batch size (default: 16)
- `LEARNING_RATE`: Initial learning rate (default: 1e-4)
- `VAL_SPLIT`: Validation split ratio (default: 0.2)

## 📈 Results

The model achieves high accuracy on Indonesian product recognition with:
- Balanced class weights for fair training
- Aggressive augmentation to prevent overfitting
- Dropout regularization for better generalization
- TFLite optimization for mobile deployment

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is open source and available under the MIT License.

## 🔗 Related Projects

- **[Sugar Check AI](https://github.com/DhanyDelio/sugar-check-ai)** - Mobile application that uses the trained model from this repository

## 🙏 Acknowledgments

- **OpenFoodFacts** for providing the product database
- **TensorFlow** for the deep learning framework
- **Google Colab** for free GPU access

## 📧 Contact

For questions or feedback, please open an issue on GitHub.

---

**Note:** This project is designed to run on Google Colab with GPU acceleration. Make sure to enable GPU runtime for optimal performance.
