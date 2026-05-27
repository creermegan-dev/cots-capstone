import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Soft underwater gradient with faint wave and coral-inspired shapes.
class OceanBackground extends StatelessWidget {
  const OceanBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFE8F7FA),
                Color(0xFFD4EFF5),
                Color(0xFFB8E3EC),
                Color(0xFF9DD8E0),
              ],
              stops: [0.0, 0.35, 0.7, 1.0],
            ),
          ),
        ),
        CustomPaint(painter: _OceanDecorPainter(), size: Size.infinite),
        child,
      ],
    );
  }
}

class _OceanDecorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void wave(Color color, double yBase, double amp, double phase) {
      final path = Path();
      path.moveTo(0, yBase);
      for (double x = 0; x <= w; x += 6) {
        final y = yBase +
            amp *
                math.sin((x / w * 2 * math.pi * 1.4) + phase);
        path.lineTo(x, y);
      }
      path.lineTo(w, h);
      path.lineTo(0, h);
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }

    wave(const Color(0x331F7A7A), h * 0.62, 14, 0.2);
    wave(const Color(0x221F7A7A), h * 0.72, 18, 1.1);

    // Soft coral-like blobs (circles / rounded shapes)
    final blobPaint = Paint()..color = const Color(0x182EC4C4);
    canvas.drawCircle(Offset(w * 0.12, h * 0.82), w * 0.08, blobPaint);
    canvas.drawCircle(Offset(w * 0.88, h * 0.76), w * 0.06, blobPaint);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.55, h * 0.92),
        width: w * 0.35,
        height: h * 0.06,
      ),
      blobPaint,
    );

    // Light shimmer arcs near top
    final arcPaint = Paint()
      ..color = const Color(0x14256D85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromLTWH(-w * 0.1, -h * 0.05, w * 0.9, h * 0.35),
      0.2,
      1.2,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
