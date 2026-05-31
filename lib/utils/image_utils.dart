import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class ImageUtils {
  /// Debug flag — set to true to swap R↔B channels.
  /// Useful for diagnosing whether the model was trained with BGR input.
  static const bool debugSwapRB = false;

  /// Convert a CameraImage (YUV420 / format 0x21) to an RGB [img.Image].
  ///
  /// Android cameras output raw YUV420 format natively.
  /// Y = luminance, U/V = chrominance.
  /// Conversion uses ITU-R BT.601 standard coefficients.
  static img.Image convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final int yRowStride = yPlane.bytesPerRow;
    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

    final rgbImage = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * yRowStride + x;
        final int uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
        final int safeUvIndex = uvIndex.clamp(0, uPlane.bytes.length - 1);
        final int safeVIndex = uvIndex.clamp(0, vPlane.bytes.length - 1);

        final int yp = yPlane.bytes[yIndex.clamp(0, yPlane.bytes.length - 1)];
        final int up = uPlane.bytes[safeUvIndex];
        final int vp = vPlane.bytes[safeVIndex];

        // ITU-R BT.601 YUV → RGB
        int r = (yp + 1.370705 * (vp - 128)).toInt().clamp(0, 255);
        int g = (yp - 0.337633 * (up - 128) - 0.698001 * (vp - 128)).toInt().clamp(0, 255);
        int b = (yp + 1.732446 * (up - 128)).toInt().clamp(0, 255);

        if (debugSwapRB) {
          final int tmp = r; r = b; b = tmp;
        }

        rgbImage.setPixelRgb(x, y, r, g, b);
      }
    }
    return rgbImage;
  }

  /// Center-crop to 1:1 aspect ratio then resize to [targetSize] x [targetSize].
  /// Prevents image distortion before AI inference.
  static img.Image cropAndResize(img.Image source, int targetSize) {
    final int srcW = source.width;
    final int srcH = source.height;
    final int cropSize = srcW < srcH ? srcW : srcH;
    final int offsetX = (srcW - cropSize) ~/ 2;
    final int offsetY = (srcH - cropSize) ~/ 2;

    debugPrint("✂️ Crop: ${srcW}x$srcH → ${cropSize}x$cropSize → ${targetSize}x$targetSize");

    final img.Image cropped = img.copyCrop(
      source,
      x: offsetX,
      y: offsetY,
      width: cropSize,
      height: cropSize,
    );

    return img.copyResize(cropped, width: targetSize, height: targetSize);
  }
}
