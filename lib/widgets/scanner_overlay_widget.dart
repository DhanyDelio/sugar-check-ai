import 'package:flutter/material.dart';

/// Overlay visual di atas camera preview — menampilkan bracket sudut
/// sebagai panduan framing kemasan produk.
class ScannerOverlayWidget extends StatelessWidget {
  const ScannerOverlayWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 260,
        height: 260,
        child: CustomPaint(
          painter: _BracketPainter(),
        ),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double bracketLength = 28.0;
    final double w = size.width;
    final double h = size.height;

    // Top-left
    canvas.drawLine(Offset(0, bracketLength), Offset(0, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(bracketLength, 0), paint);

    // Top-right
    canvas.drawLine(Offset(w - bracketLength, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, bracketLength), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, h - bracketLength), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(bracketLength, h), paint);

    // Bottom-right
    canvas.drawLine(Offset(w - bracketLength, h), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - bracketLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
