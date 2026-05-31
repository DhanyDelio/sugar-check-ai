import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Handles hardware-level camera operations (focus, exposure).
/// Separated from UI logic to keep CameraPreviewWidget clean.
class CameraHelperService {
  /// Apply tap-to-focus at the given screen position.
  /// Converts screen coordinates to normalized [0.0, 1.0] range required by the camera plugin.
  static Future<void> applyTouchFocus({
    required CameraController controller,
    required TapDownDetails details,
    required BuildContext context,
  }) async {
    try {
      final screenSize = MediaQuery.of(context).size;
      final double x = details.localPosition.dx / screenSize.width;
      final double y = details.localPosition.dy / screenSize.height;
      final Offset focusPoint = Offset(x, y);

      await controller.setFocusPoint(focusPoint);
      await controller.setExposurePoint(focusPoint);
      await controller.setFocusMode(FocusMode.locked);
      await Future.delayed(const Duration(milliseconds: 500));
      await controller.setFocusMode(FocusMode.auto);

      debugPrint("🎯 Focus applied at: ($x, $y)");
    } catch (e) {
      debugPrint("❌ Focus failed: $e");
    }
  }
}
