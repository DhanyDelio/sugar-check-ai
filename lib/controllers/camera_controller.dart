import 'dart:async';
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
  String? errorMessage;
  List<Uint8List> silentFrames = [];

  // True if the camera image stream terminated with an error.
  // Checked in onCapturePressed before proceeding — prevents silent failure.
  bool _silentCaptureError = false;
  Completer<void>? _silentCaptureCompleter;

  bool isFlashOn = false;
  bool _hasCheckedBrightness = false;

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
      await releaseCamera();

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
      await releaseCamera();

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
    if (controller!.value.isStreamingImages) {
      await controller!.stopImageStream();
    }
    await _startSilentCapture();
  }

  // ── Silent capture ────────────────────────────────────────────────────────

  Future<void> _startSilentCapture() async {
    _silentCaptureError = false;
    _hasCheckedBrightness = false;
    _silentCaptureCompleter = Completer<void>();
    try {
      int frameCount = 0;
      DateTime lastFrameTime = DateTime.now();
      silentFrames.clear();

      await controller!.startImageStream((CameraImage image) {
        final now = DateTime.now();

        // Light meter: auto-enable flash if too dark
        if (!_hasCheckedBrightness) {
          _hasCheckedBrightness = true;
          try {
            int total = 0;
            final bytes = image.planes[0].bytes;
            final step = bytes.length ~/ 100;
            if (step > 0) {
              for (int i = 0; i < bytes.length; i += step) {
                total += bytes[i];
              }
              final avg = total / 100;
              if (avg < 40 && !isFlashOn) {
                debugPrint("💡 Light meter: Low light detected ($avg). User can manually enable flash if needed.");
                // auto-enable flash is removed per user request: default false.
              }
            }
          } catch (e) {
            debugPrint("⚠️ Light meter error: $e");
          }
        }

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
            if (_silentCaptureCompleter != null && !_silentCaptureCompleter!.isCompleted) {
              _silentCaptureCompleter!.complete();
            }
          }
        }
      });
    } catch (e) {
      debugPrint("❌ Silent capture error: $e");
      _silentCaptureError = true;
      if (_silentCaptureCompleter != null && !_silentCaptureCompleter!.isCompleted) {
        _silentCaptureCompleter!.complete();
      }
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

    // Fully release camera hardware before navigating away so OS flash works on Edit Screen
    await releaseCamera();

    await NavigationService.navigateTo(
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

    // Re-initialize camera when returning to this screen
    await initCamera();
  }

  // ── Public actions ────────────────────────────────────────────────────────

  Future<void> toggleFlash(bool isOn) async {
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isTakingPicture) return;

    try {
      await controller!.setFlashMode(isOn ? FlashMode.torch : FlashMode.off);
      isFlashOn = isOn;
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Flash toggle error: $e");
    }
  }

  Future<void> onCapturePressed(String userEmail) async {
    if (isAnalyzing || controller == null || !controller!.value.isInitialized) return;

    // Clear any previous error so UI resets on retry
    errorMessage = null;
    notifyListeners();

    try {
      // Wait for silent frames if still collecting
      if (silentFrames.length < _silentFrameCount &&
          controller!.value.isStreamingImages &&
          !_silentCaptureError) {
        _setLoading(true, "Preparing camera...");
        debugPrint("⏳ Waiting for silent frames (${silentFrames.length}/$_silentFrameCount)...");
        
        try {
          if (_silentCaptureCompleter != null) {
            await _silentCaptureCompleter!.future.timeout(const Duration(seconds: 5));
          }
        } catch (e) {
          debugPrint("⚠️ Wait for silent frames timed out or errored: $e");
        }
        
        debugPrint("✅ Silent frames ready: ${silentFrames.length}/$_silentFrameCount");
      }

      // Abort if the camera stream failed — don't silently proceed with 0 frames
      if (_silentCaptureError && silentFrames.isEmpty) {
        _setError("Camera error — please tap capture again");
        return;
      }

      _setLoading(true, _loadingMessages[0]);
      if (controller!.value.isStreamingImages) {
        await controller!.stopImageStream();
      }

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

  /// Surface a recoverable error to the UI. Clears the loading state.
  void _setError(String message) {
    isAnalyzing = false;
    loadingMessage = '';
    errorMessage = message;
    notifyListeners();
  }

  // ── Dispose & Release ─────────────────────────────────────────────────────

  /// Completely stops the stream, turns off the flash, and releases the hardware.
  Future<void> releaseCamera() async {
    final CameraController? temp = controller;
    if (temp == null) return;
    
    // Set to null immediately so UI shows loading instead of frozen preview
    controller = null;
    notifyListeners();

    try {
      // 1. Stop stream if active
      if (temp.value.isInitialized && temp.value.isStreamingImages) {
        await temp.stopImageStream();
        debugPrint("⏸ Stream stopped before release");
      }
      // 2. Turn off flash if active
      if (isFlashOn && temp.value.isInitialized) {
        await temp.setFlashMode(FlashMode.off);
        isFlashOn = false;
        debugPrint("🔦 Flash turned off before release");
      }
      // 3. Dispose hardware
      await temp.dispose();
      debugPrint("✅ Camera hardware fully released.");
    } catch (e) {
      debugPrint("❌ Error releasing camera: $e");
    }
  }

  @override
  void dispose() {
    releaseCamera();
    super.dispose();
  }
}
