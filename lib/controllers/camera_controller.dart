import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:sugarcheck/core/navigation/navigation_service.dart';
import '../services/tflite_service.dart';
import '../utils/image_utils.dart';
import '../utils/string_utils.dart';
import '../screens/sugar_edit_screen.dart';
import '../models/scan_result.dart';

class ScannerController with ChangeNotifier {
  CameraController? controller;
  final TfliteService _tfliteService = TfliteService();

  bool isAnalyzing = false;
  String loadingMessage = "";
  List<Uint8List> silentFrames = [];

  // Number of silent frames collected per scan session for dataset diversity
  static const int _silentFrameCount = 9;
  // Interval between frames to capture varied angles
  static const int _silentFrameIntervalMs = 500;
  // Pre-resize width before center-crop to 224x224 for AI inference
  static const int _aiPreResizeWidth = 800;
  // Display image width for UI rendering
  static const int _displayImageWidth = 400;

  static const List<String> _loadingMessages = [
    "Analyzing packaging...",
    "Recognizing product...",
    "Calculating sugar content...",
    "Processing results...",
  ];

  Future<void> initCamera() async {
    try {
      if (controller != null) {
        await controller!.dispose();
        controller = null;
      }

      notifyListeners();

      await _tfliteService.initializeModel();
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint("❌ Camera not found");
        return;
      }

      final backCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        backCam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller!.initialize();
      notifyListeners();

      // Silent capture: collect frames in background while user aims the camera
      int frameCount = 0;
      DateTime lastFrameTime = DateTime.now();
      silentFrames.clear();

      await controller!.startImageStream((CameraImage image) {
        final now = DateTime.now();
        if (frameCount < _silentFrameCount &&
            now.difference(lastFrameTime).inMilliseconds > _silentFrameIntervalMs) {
          // Convert YUV420 (native Android camera format) to RGB for storage
          final img.Image converted = ImageUtils.convertYUV420ToImage(image);
          final Uint8List compressed = Uint8List.fromList(
            img.encodeJpg(converted, quality: 35),
          );
          silentFrames.add(compressed);
          frameCount++;
          lastFrameTime = now;
          debugPrint("📸 Silent frame $frameCount/$_silentFrameCount captured");
        } else if (frameCount >= _silentFrameCount) {
          if (controller!.value.isStreamingImages) {
            controller!.stopImageStream();
            debugPrint("✅ Silent capture done ($_silentFrameCount frames).");
          }
        }
      });
    } catch (e) {
      debugPrint("❌ Initialization Error: $e");
    }
  }

  Future<void> onCapturePressed(String userEmail) async {
    if (isAnalyzing || controller == null || !controller!.value.isInitialized) return;

    try {
      _setLoading(true, _loadingMessages[0]);

      // Stop stream to avoid conflict with takePicture
      if (controller!.value.isStreamingImages) {
        await controller!.stopImageStream();
        debugPrint("⏸ Stream stopped for takePicture");
      }

      // 1. Capture photo
      final XFile photo = await controller!.takePicture();
      final Uint8List originalBytes = await photo.readAsBytes();
      debugPrint("📷 takePicture: ${originalBytes.length} bytes");

      final img.Image? decodedImg = img.decodeImage(originalBytes);
      if (decodedImg == null) {
        debugPrint("❌ decodeImage failed");
        return;
      }
      debugPrint("🖼 Decoded: ${decodedImg.width}x${decodedImg.height}");

      // 2. Resize for UI display
      _setLoading(true, _loadingMessages[1]);
      final img.Image displayImg = img.copyResize(decodedImg, width: _displayImageWidth);
      final Uint8List capturedFrame = Uint8List.fromList(
        img.encodeJpg(displayImg, quality: 60),
      );

      // 3. AI inference — pre-resize then center-crop to 224x224 inside runInference
      _setLoading(true, _loadingMessages[2]);
      final img.Image aiImg = img.copyResize(decodedImg, width: _aiPreResizeWidth);
      final ScanResult result = await _tfliteService.runInference(aiImg);

      _setLoading(true, _loadingMessages[3]);

      // 4. Auto-fill product name if confidence >= 50%
      String productName = "";
      if (result.isConfident) {
        productName = formatLabel(result.product);
        debugPrint("✅ Auto-fill: $productName (${result.confidence.toStringAsFixed(1)}%)");
      } else {
        debugPrint("⚠️ Low confidence (${result.confidence.toStringAsFixed(1)}%) — field left empty");
      }

      // 5. Navigate to Edit Screen
      _setLoading(false, "");
      NavigationService.navigateTo(
        SugarEditScreen(
          ocrImage: capturedFrame,
          silentImages: List.from(silentFrames),
          initialSugar: 0,
          initialProductName: productName,
          userEmail: userEmail,
          suggestionName: result.isConfident ? null : formatLabel(result.product),
          confidence: result.confidence,
        ),
      );
      silentFrames.clear();
    } catch (e) {
      debugPrint("❌ Capture Error: $e");
      _setLoading(false, "");
    }
  }

  void _setLoading(bool value, String message) {
    isAnalyzing = value;
    loadingMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
