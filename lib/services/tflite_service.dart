import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:firebase_ml_model_downloader/firebase_ml_model_downloader.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import '../models/scan_result.dart';
import '../utils/image_utils.dart';

class TfliteService {
  Interpreter? _interpreter;
  Map<String, String>? _labelMap;
  bool _isInitializing = false;

  static const double _confidenceThreshold = 50.0;

  bool get isReady => _interpreter != null && _labelMap != null;

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initializeModel() async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      // Try remote model first (Firebase ML), fall back to bundled asset
      final customModel = await FirebaseModelDownloader.instance.getModel(
        "SugarClassifierV1",
        FirebaseModelDownloadType.localModelUpdateInBackground,
      );
      _interpreter = Interpreter.fromFile(customModel.file);
      debugPrint("✅ AI: Remote model loaded.");
    } catch (e) {
      debugPrint("⚠️ AI: Firebase failed. Loading local asset...");
      try {
        _interpreter = await Interpreter.fromAsset('assets/models/sugar_checker.tflite');
        debugPrint("✅ AI: Local model loaded.");
      } catch (assetError) {
        debugPrint("❌ AI: CRITICAL — $assetError");
      }
    }

    await _loadLabels();
    _isInitializing = false;
  }

  Future<void> _loadLabels() async {
    try {
      final String json = await rootBundle.loadString('assets/models/labels.json');
      final Map<String, dynamic> data = jsonDecode(json);

      // Store as Map<String, String> — key matches raw model output index
      // No sorting or reordering: JSON index == model output index
      _labelMap = data.map((k, v) => MapEntry(k, v.toString().trim()));

      debugPrint("✅ Labels loaded: ${_labelMap!.length} classes");
    } catch (e) {
      debugPrint("❌ Labels load error: $e");
    }
  }

  // ── Inference ─────────────────────────────────────────────────────────────

  /// Run inference and return a [ScanResult].
  /// Confidence threshold: $_confidenceThreshold%
  Future<ScanResult> runInference(img.Image originalImage) async {
    if (!isReady) {
      return const ScanResult(product: "Model Not Ready", confidence: 0, isConfident: false);
    }

    final int numClasses = _labelMap!.length;

    // Center-crop to 1:1 then resize to 224x224 — prevents distortion
    final img.Image aiInput = ImageUtils.cropAndResize(originalImage, 224);
    debugPrint("📸 Inference input: ${aiInput.width}x${aiInput.height}");

    final Uint8List input = _imageToByteListFloat32(aiInput, 224);
    final output = List.filled(numClasses, 0.0).reshape([1, numClasses]);

    _interpreter!.run(input, output);

    // Find highest scoring class
    double highestScore = -double.infinity;
    int rawMaxIndex = 0;
    for (int i = 0; i < numClasses; i++) {
      final double score = output[0][i] as double;
      if (score > highestScore) {
        highestScore = score;
        rawMaxIndex = i;
      }
    }

    final String product = _labelMap![rawMaxIndex.toString()] ?? "Unknown ($rawMaxIndex)";
    final double confidence = highestScore * 100;

    // Log top 3 predictions for debugging
    final List<MapEntry<int, double>> scores = List.generate(
      numClasses,
      (i) => MapEntry(i, output[0][i] as double),
    )..sort((a, b) => b.value.compareTo(a.value));

    debugPrint("🏆 Top 3 predictions:");
    for (int i = 0; i < 3 && i < scores.length; i++) {
      final label = _labelMap![scores[i].key.toString()] ?? "Unknown";
      final pct = (scores[i].value * 100).toStringAsFixed(2);
      debugPrint("  #${i + 1} → $label ($pct%)");
    }

    debugPrint("🎯 Result: $product — ${confidence.toStringAsFixed(1)}%");

    return ScanResult(
      product: product,
      confidence: confidence,
      isConfident: confidence >= _confidenceThreshold,
    );
  }

  // ── Image preprocessing ───────────────────────────────────────────────────

  /// Convert image to Float32 buffer using MobileNetV2 normalization:
  /// pixel = (value / 127.5) - 1.0  →  range [-1.0, 1.0]
  Uint8List _imageToByteListFloat32(img.Image image, int size) {
    final buffer = Float32List(size * size * 3);
    int idx = 0;
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final pixel = image.getPixel(x, y);
        buffer[idx++] = (pixel.r / 127.5) - 1.0;
        buffer[idx++] = (pixel.g / 127.5) - 1.0;
        buffer[idx++] = (pixel.b / 127.5) - 1.0;
      }
    }
    return buffer.buffer.asUint8List();
  }

  void dispose() {
    _interpreter?.close();
  }
}
