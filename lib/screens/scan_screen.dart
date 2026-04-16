import 'package:flutter/material.dart';
import '../controllers/camera_controller.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/capture_button_widget.dart';
import '../widgets/scanner_overlay_widget.dart';
import '../widgets/loading_overlay_widget.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ScannerController _scannerLogic = ScannerController();
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _scannerLogic.initCamera().then((_) {
      if (mounted) setState(() => _isReady = true);
    });
  }

  @override
  void dispose() {
    _scannerLogic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: _scannerLogic,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Camera preview
              _isReady
                  ? CameraPreviewWidget(controller: _scannerLogic.controller!)
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.green),
                    ),

              // Framing overlay
              const ScannerOverlayWidget(),

              // Capture button
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: CaptureButtonWidget(
                    onTap: _scannerLogic.isAnalyzing
                        ? () {}
                        : () => _scannerLogic.onCapturePressed("test@gmail.com"),
                  ),
                ),
              ),

              // Back button
              Positioned(
                top: 40,
                left: 20,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                ),
              ),

              // Loading overlay during AI processing
              if (_scannerLogic.isAnalyzing)
                LoadingOverlay(
                  message: _scannerLogic.loadingMessage,
                  subMessage: "Point the camera at the nutrition label",
                ),
            ],
          );
        },
      ),
    );
  }
}
