import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_helper_service.dart'; // Import service tadi

class CameraPreviewWidget extends StatefulWidget {
  final CameraController controller;
  const CameraPreviewWidget({super.key, required this.controller});

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  Offset? _visualFocusPoint;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTapDown: (details) async {
            // Panggil service buat urusan hardware
            await CameraHelperService.applyTouchFocus(
              controller: widget.controller,
              details: details,
              context: context,
            );

            // Urusan UI (kotak kuning) tetep di sini
            setState(() => _visualFocusPoint = details.localPosition);
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) setState(() => _visualFocusPoint = null);
            });
          },
          child: CameraPreview(widget.controller),
        ),

        // Kotak kuning indikator fokus
        if (_visualFocusPoint != null)
          Positioned(
            left: _visualFocusPoint!.dx - 25,
            top: _visualFocusPoint!.dy - 25,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.yellow, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
