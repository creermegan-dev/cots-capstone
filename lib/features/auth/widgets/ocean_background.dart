import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'auth_layout.dart';

/// Minimal marine gradient with subtle wave and coral-inspired shapes.
class OceanBackground extends StatelessWidget {
  const OceanBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final desktop = authLayoutModeOf(context) != AuthLayoutMode.mobile;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: desktop
                  ? const [AuthTokens.bgTop, AuthTokens.bgBottom]
                  : const [
                      Color(0xFFE8F7FA),
                      Color(0xFFD4EFF5),
                      Color(0xFFB8E3EC),
                      Color(0xFF9DD8E0),
                    ],
              stops: desktop ? null : const [0.0, 0.35, 0.7, 1.0],
            ),
          ),
        ),
        CustomPaint(
          painter: _OceanDecorPainter(subtle: desktop),
          size: Size.infinite,
        ),
        child,
      ],
    );
  }
}

class _OceanDecorPainter extends CustomPainter {
  const _OceanDecorPainter({required this.subtle});

  final bool subtle;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final alpha = subtle ? 0.06 : 0.14;

    void wave(Color color, double yBase, double amp, double phase) {
      final path = Path();
      path.moveTo(0, yBase);
      for (double x = 0; x <= w; x += 8) {
        final y = yBase + amp * math.sin((x / w * 2 * math.pi * 1.2) + phase);
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

    if (subtle) {
      wave(AuthTokens.focusTeal.withValues(alpha: 0.04), h * 0.78, 10, 0.3);
      wave(AuthTokens.focusTeal.withValues(alpha: 0.03), h * 0.88, 8, 1.4);
    } else {
      wave(const Color(0x331F7A7A), h * 0.62, 14, 0.2);
      wave(const Color(0x221F7A7A), h * 0.72, 18, 1.1);
    }

    final blobPaint = Paint()
      ..color = AuthTokens.focusTeal.withValues(alpha: alpha);
    canvas.drawCircle(Offset(w * 0.08, h * 0.18), w * 0.05, blobPaint);
    canvas.drawCircle(Offset(w * 0.92, h * 0.22), w * 0.04, blobPaint);
    canvas.drawCircle(Offset(w * 0.15, h * 0.75), w * 0.06, blobPaint);
    canvas.drawCircle(Offset(w * 0.85, h * 0.68), w * 0.045, blobPaint);

    if (!subtle) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.55, h * 0.92),
          width: w * 0.35,
          height: h * 0.06,
        ),
        blobPaint,
      );
    }

    final arcPaint = Paint()
      ..color = AuthTokens.focusTeal.withValues(alpha: subtle ? 0.05 : 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawArc(
      Rect.fromLTWH(-w * 0.05, -h * 0.02, w * 0.7, h * 0.28),
      0.3,
      1.0,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _OceanDecorPainter oldDelegate) =>
      oldDelegate.subtle != subtle;
}
