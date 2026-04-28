import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
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

  static const int _silentFrameCount      = 9;
  static const int _silentFrameIntervalMs = 500;
  static const int _aiPreResizeWidth      = 800;
  static const int _displayImageWidth     = 400;

  static const List<String> _loadingMessages = [
    "Analyzing packaging...",
    "Recognizing product...",
    "Calculating sugar content...",
    "Processing results...",
  ];

  // ── Camera init ───────────────────────────────────────────────────────────

  List<CameraDescription> _availableCameras = [];
  CameraDescription? _currentCamera;

  bool get isBackCamera =>
      _currentCamera?.lensDirection == CameraLensDirection.back;

  Future<void> initCamera() async {
    try {
      await _stopStreamSafely();
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

      _availableCameras = cameras;
      final backCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _currentCamera = backCam;
      await _initWithCamera(backCam);
    } catch (e) {
      debugPrint("❌ Initialization Error: $e");
    }
  }

  Future<void> flipCamera() async {
    if (_availableCameras.length < 2 || isAnalyzing) return;
    final next = _availableCameras.firstWhere(
      (c) => c.lensDirection !=
          (_currentCamera?.lensDirection ?? CameraLensDirection.back),
      orElse: () => _availableCameras.first,
    );
    _currentCamera = next;
    await _initWithCamera(next);
  }

  Future<void> _initWithCamera(CameraDescription camera) async {
    try {
      await _stopStreamSafely();
      if (controller != null) {
        await controller!.dispose();
        controller = null;
        notifyListeners();
      }
      controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller!.initialize();
      notifyListeners();
      await _startSilentCapture();
    } catch (e) {
      debugPrint("❌ Camera init error: $e");
    }
  }

  Future<void> restartSilentCapture() async {
    if (controller == null || !controller!.value.isInitialized) return;
    await _stopStreamSafely();
    await _startSilentCapture();
  }

  // ── Silent capture ────────────────────────────────────────────────────────

  Future<void> _startSilentCapture() async {
    try {
      int frameCount = 0;
      DateTime lastFrameTime = DateTime.now();
      silentFrames.clear();

      await controller!.startImageStream((CameraImage image) {
        final now = DateTime.now();
        if (frameCount < _silentFrameCount &&
            now.difference(lastFrameTime).inMilliseconds > _silentFrameIntervalMs) {
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
      debugPrint("❌ Silent capture error: $e");
    }
  }

  // ── Core image processing — shared by capture and gallery ─────────────────

  /// Decode, resize for display + AI, run inference, navigate to edit screen.
  /// [capturedSilentFrames] is empty for gallery images.
  Future<void> _processImage({
    required Uint8List originalBytes,
    required String userEmail,
    required List<Uint8List> capturedSilentFrames,
  }) async {
    final img.Image? decodedImg = img.decodeImage(originalBytes);
    if (decodedImg == null) {
      debugPrint("❌ decodeImage failed");
      _setLoading(false, "");
      return;
    }
    debugPrint("🖼 Decoded: ${decodedImg.width}x${decodedImg.height}");

    // Resize for UI display
    _setLoading(true, _loadingMessages[1]);
    final img.Image displayImg =
        img.copyResize(decodedImg, width: _displayImageWidth);
    final Uint8List capturedFrame = Uint8List.fromList(
      img.encodeJpg(displayImg, quality: 60),
    );

    // AI inference
    _setLoading(true, _loadingMessages[2]);
    final img.Image aiImg =
        img.copyResize(decodedImg, width: _aiPreResizeWidth);
    final ScanResult result = await _tfliteService.runInference(aiImg);

    _setLoading(true, _loadingMessages[3]);

    final String productName = result.isConfident
        ? formatLabel(result.product)
        : "";

    if (result.isConfident) {
      debugPrint("✅ Auto-fill: $productName (${result.confidence.toStringAsFixed(1)}%)");
    } else {
      debugPrint("⚠️ Low confidence (${result.confidence.toStringAsFixed(1)}%) — field left empty");
    }

    _setLoading(false, "");
    NavigationService.navigateTo(
      SugarEditScreen(
        ocrImage: capturedFrame,
        silentImages: capturedSilentFrames,
        initialSugar: 0,
        initialProductName: productName,
        userEmail: userEmail,
        suggestionName: result.isConfident ? null : formatLabel(result.product),
        confidence: result.confidence,
      ),
    );
  }

  // ── Public actions ────────────────────────────────────────────────────────

  Future<void> onCapturePressed(String userEmail) async {
    if (isAnalyzing || controller == null || !controller!.value.isInitialized) return;

    try {
      // Wait for silent frames if still collecting
      if (silentFrames.length < _silentFrameCount &&
          controller!.value.isStreamingImages) {
        _setLoading(true, "Preparing camera...");
        debugPrint("⏳ Waiting for silent frames (${silentFrames.length}/$_silentFrameCount)...");
        int waited = 0;
        while (silentFrames.length < _silentFrameCount && waited < 5000) {
          await Future.delayed(const Duration(milliseconds: 200));
          waited += 200;
        }
        debugPrint("✅ Silent frames ready: ${silentFrames.length}/$_silentFrameCount");
      }

      _setLoading(true, _loadingMessages[0]);
      await _stopStreamSafely();

      final XFile photo = await controller!.takePicture();
      final Uint8List originalBytes = await photo.readAsBytes();
      debugPrint("📷 takePicture: ${originalBytes.length} bytes");

      final List<Uint8List> frames = List.from(silentFrames);
      silentFrames.clear();

      await _processImage(
        originalBytes: originalBytes,
        userEmail: userEmail,
        capturedSilentFrames: frames,
      );
    } catch (e) {
      debugPrint("❌ Capture Error: $e");
      _setLoading(false, "");
    }
  }

  Future<void> onGalleryPressed(String userEmail) async {
    if (isAnalyzing) return;

    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;

      _setLoading(true, _loadingMessages[0]);
      final Uint8List originalBytes = await picked.readAsBytes();

      await _processImage(
        originalBytes: originalBytes,
        userEmail: userEmail,
        capturedSilentFrames: const [], // no silent frames for gallery
      );
    } catch (e) {
      debugPrint("❌ Gallery Error: $e");
      _setLoading(false, "");
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setLoading(bool value, String message) {
    isAnalyzing = value;
    loadingMessage = message;
    notifyListeners();
  }

  /// Safely stop image stream — no-op if not streaming.
  Future<void> _stopStreamSafely() async {
    try {
      if (controller != null &&
          controller!.value.isInitialized &&
          controller!.value.isStreamingImages) {
        await controller!.stopImageStream();
        debugPrint("⏸ Stream stopped");
      }
    } catch (_) {}
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    // Stop stream before disposing to prevent memory leaks
    _stopStreamSafely().then((_) => controller?.dispose());
    super.dispose();
  }
}
