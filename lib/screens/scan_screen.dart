import 'package:flutter/material.dart';
import '../controllers/camera_controller.dart';
import '../screens/main_screen.dart';
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
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    // Fixed height for the bottom control bar
    const double controlBarHeight = 96.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: _scannerLogic,
        builder: (context, _) {
          return Column(
            children: [
              // ── Camera area — takes all space above the control bar ──────
              Expanded(
                child: Stack(
                  children: [
                    // Camera preview fills the camera area
                    Positioned.fill(
                      child: _isReady
                          ? CameraPreviewWidget(
                              controller: _scannerLogic.controller!)
                          : const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.green),
                            ),
                    ),

                    // Bracket overlay — centered inside camera area
                    const ScannerOverlayWidget(),

                    // Back button
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 8,
                      child: IconButton(
                        onPressed: () => MainScreen.switchToHome(),
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 30),
                      ),
                    ),

                    // Loading overlay
                    if (_scannerLogic.isAnalyzing)
                      LoadingOverlay(
                        message: _scannerLogic.loadingMessage,
                        subMessage: "Point the camera at the nutrition label",
                      ),
                  ],
                ),
              ),

              // ── Control bar — always below camera, never overlaps ────────
              Container(
                width: double.infinity,
                height: controlBarHeight + bottomPadding,
                color: Colors.black,
                padding: EdgeInsets.only(
                  top: 12,
                  bottom: bottomPadding + 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Flip camera
                    _ControlButton(
                      icon: Icons.flip_camera_ios_outlined,
                      onTap: _scannerLogic.isAnalyzing
                          ? null
                          : () async {
                              await _scannerLogic.flipCamera();
                              if (mounted) setState(() {});
                            },
                    ),

                    // Capture
                    CaptureButtonWidget(
                      onTap: _scannerLogic.isAnalyzing
                          ? () {}
                          : () => _scannerLogic
                              .onCapturePressed("test@gmail.com"),
                    ),

                    // Gallery
                    _ControlButton(
                      icon: Icons.photo_library_outlined,
                      onTap: _scannerLogic.isAnalyzing
                          ? null
                          : () => _scannerLogic
                              .onGalleryPressed("test@gmail.com"),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _ControlButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white38, width: 1.5),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
