import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../landing_theme.dart';

/// Subtle topographic contour lines for the underwater tech aesthetic.
class LandingContourPainter extends CustomPainter {
  LandingContourPainter({this.opacity = 0.18});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = LandingColors.teal.withValues(alpha: opacity);

    final w = size.width;
    final h = size.height;

    for (var i = 0; i < 9; i++) {
      final path = Path();
      final baseY = h * (0.15 + i * 0.09);
      path.moveTo(-w * 0.05, baseY);
      for (var x = 0.0; x <= w * 1.05; x += 8) {
        final y = baseY +
            math.sin((x / w) * math.pi * 2.2 + i * 0.7) * (12 + i * 2.5) +
            math.cos((x / w) * math.pi * 1.1 + i) * 8;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant LandingContourPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
