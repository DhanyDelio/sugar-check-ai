import 'package:flutter/material.dart';

/// Bracket overlay centered inside the camera preview area.
/// Since the camera area is now a separate Expanded widget (not full screen),
/// this widget simply centers itself — no manual offset calculation needed.
class ScannerOverlayWidget extends StatelessWidget {
  const ScannerOverlayWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // 72% of screen width, but never taller than 60% of available height
    final double size = MediaQuery.of(context).size.width * 0.72;

    return Center(
      child: SizedBox(
        width: size,
        height: size,
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

    const double bracketLength = 32.0;
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
