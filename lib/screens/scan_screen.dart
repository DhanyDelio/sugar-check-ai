import 'package:flutter/material.dart';
import '../controllers/camera_controller.dart';
import '../screens/main_screen.dart';
import '../services/user_id_service.dart';
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
  String _userId = '';

  static const double _controlBarHeight = 96.0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _userId = await UserIdService.getUserId();
    await _scannerLogic.initCamera();
    if (mounted) setState(() => _isReady = true);
  }

  @override
  void dispose() {
    _scannerLogic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: _scannerLogic,
        builder: (context, _) {
          // Show error as a SnackBar, then clear so it doesn't repeat on rebuild
          if (_scannerLogic.errorMessage != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_scannerLogic.errorMessage!),
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                ),
              );
              _scannerLogic.errorMessage = null;
            });
          }
          return Column(
            children: [
              // ── Camera area ──────────────────────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: (_isReady && _scannerLogic.controller != null && _scannerLogic.controller!.value.isInitialized)
                          ? CameraPreviewWidget(
                              controller: _scannerLogic.controller!)
                          : const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.green),
                            ),
                    ),
                    const ScannerOverlayWidget(),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 8,
                      child: IconButton(
                        onPressed: () => MainScreen.switchToHome(),
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 30),
                      ),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      right: 8,
                      child: IconButton(
                        onPressed: _scannerLogic.isAnalyzing
                            ? null
                            : () => _scannerLogic.toggleFlash(!_scannerLogic.isFlashOn),
                        icon: Icon(
                          _scannerLogic.isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: _scannerLogic.isAnalyzing ? Colors.white38 : Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    if (_scannerLogic.isAnalyzing)
                      LoadingOverlay(
                        message: _scannerLogic.loadingMessage,
                      ),
                  ],
                ),
              ),

              // ── Control bar ──────────────────────────────────────────────
              Container(
                width: double.infinity,
                height: _controlBarHeight + bottomPadding,
                color: Colors.black,
                padding: EdgeInsets.only(
                  top: 12,
                  bottom: bottomPadding + 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ControlButton(
                      icon: Icons.flip_camera_ios_outlined,
                      onTap: _scannerLogic.isAnalyzing
                          ? null
                          : () async {
                              await _scannerLogic.flipCamera();
                              if (mounted) setState(() {});
                            },
                    ),
                    CaptureButtonWidget(
                      onTap: _scannerLogic.isAnalyzing
                          ? () {}
                          : () => _scannerLogic.onCapturePressed(_userId),
                    ),
                    _ControlButton(
                      icon: Icons.photo_library_outlined,
                      onTap: _scannerLogic.isAnalyzing
                          ? null
                          : () => _scannerLogic.onGalleryPressed(_userId),
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
