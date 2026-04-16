import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/cloudinary_service.dart';

/// Product category — determines which form fields are shown
enum ProductCategory { minuman, makanan }

class SugarEditController extends ChangeNotifier {
  final CloudinaryService _cloudinaryService = CloudinaryService();

  late TextEditingController productController;
  late TextEditingController varianController;

  // Dynamic form controllers
  // Beverage: volume_total (ml), volume_per_serving (ml), sugar_per_serving (g)
  // Food:     total_weight (g), serving_weight (g), sugar_per_serving (g)
  late TextEditingController totalController;       // volume_total / total_weight
  late TextEditingController perSajianController;   // volume_per_serving / serving_weight
  late TextEditingController gulaSajianController;  // sugar_per_serving (always grams)

  /// Active category — changing this triggers a form rebuild
  ProductCategory selectedCategory = ProductCategory.minuman;

  List<Uint8List> displayImages = [];
  List<bool> selectedImages = [];
  List<Uint8List> _silentFrames = [];
  bool isSaving = false;

  // False positive tracking — AI was confident but user corrected it
  String _aiProductName = '';
  double _aiConfidence = 0;

  /// True if AI confidence >= 80% but user changed the product name.
  /// Marks the entry as high priority for model retraining.
  bool get isHighPriority {
    if (_aiConfidence < 80.0) return false;
    if (_aiProductName.isEmpty) return false;
    return productController.text.trim().toLowerCase() !=
        _aiProductName.trim().toLowerCase();
  }

  void init(
    String productName,
    int totalSugar,
    Uint8List ocrImage,
    List<Uint8List> silentImages, {
    double confidence = 0,
  }) {
    productController = TextEditingController(text: productName);
    varianController = TextEditingController();
    totalController = TextEditingController();
    perSajianController = TextEditingController();
    gulaSajianController = TextEditingController(
      text: totalSugar > 0 ? totalSugar.toString() : '',
    );

    _aiProductName = productName;
    _aiConfidence = confidence;

    displayImages = [ocrImage];
    selectedImages = [true];
    _silentFrames = List.from(silentImages);
  }

  void setCategory(ProductCategory category) {
    if (selectedCategory == category) return;
    selectedCategory = category;
    // Reset fields on category change to avoid mixed data
    totalController.clear();
    perSajianController.clear();
    notifyListeners();
  }

  /// Formula: (sugar_per_serving / serving_size) * total_size
  int get calculatedTotalSugar {
    final double total = double.tryParse(totalController.text) ?? 0;
    final double perSajian = double.tryParse(perSajianController.text) ?? 0;
    final double gulaSajian = double.tryParse(gulaSajianController.text) ?? 0;
    if (perSajian == 0) return 0;
    return ((gulaSajian / perSajian) * total).round();
  }

  /// JSON snapshot for local debugging or export
  Map<String, dynamic> toJson() {
    if (selectedCategory == ProductCategory.minuman) {
      return {
        "category": "beverage",
        "product_name": productController.text,
        "variant": varianController.text,
        "volume_total_ml": double.tryParse(totalController.text) ?? 0,
        "volume_per_serving_ml": double.tryParse(perSajianController.text) ?? 0,
        "sugar_per_serving_g": double.tryParse(gulaSajianController.text) ?? 0,
        "total_sugar_g": calculatedTotalSugar,
      };
    } else {
      return {
        "category": "food",
        "product_name": productController.text,
        "variant": varianController.text,
        "total_weight_g": double.tryParse(totalController.text) ?? 0,
        "serving_weight_g": double.tryParse(perSajianController.text) ?? 0,
        "sugar_per_serving_g": double.tryParse(gulaSajianController.text) ?? 0,
        "total_sugar_g": calculatedTotalSugar,
      };
    }
  }

  void toggleImageSelection(int index) {
    selectedImages[index] = !selectedImages[index];
    notifyListeners();
  }

  Future<bool> uploadData(
    String userEmail,
    Uint8List originalOcr, {
    void Function(double totalSugar)? onSuccess,
  }) async {
    isSaving = true;
    notifyListeners();

    try {
      await _cloudinaryService.uploadTrainingData(
        primaryImage: originalOcr,
        silentFramesList: _silentFrames,
        sugarValue: calculatedTotalSugar,
        productName: productController.text,
        variantName: varianController.text,
        volumeTotal: double.tryParse(totalController.text) ?? 0,
        userId: userEmail,
        isHighPriority: isHighPriority,
        aiConfidence: _aiConfidence,
        aiProductName: _aiProductName,
      );
      onSuccess?.call(calculatedTotalSugar.toDouble());
      return true;
    } catch (e) {
      debugPrint("❌ Upload Error: $e");
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    productController.dispose();
    varianController.dispose();
    totalController.dispose();
    perSajianController.dispose();
    gulaSajianController.dispose();
    super.dispose();
  }
}
