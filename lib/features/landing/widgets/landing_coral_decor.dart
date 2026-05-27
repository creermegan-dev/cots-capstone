import 'package:flutter/material.dart';

import '../landing_theme.dart';

/// Subtle coral & reef silhouettes for the hero left panel.
class LandingCoralDecor extends StatelessWidget {
  const LandingCoralDecor({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _CoralSilhouettePainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _CoralSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LandingColors.teal.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;

    final stroke = Paint()
      ..color = LandingColors.teal.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Coral cluster bottom-left
    final base = Offset(size.width * 0.06, size.height * 0.88);
    _drawCoralBranch(canvas, base, paint, stroke, scale: 1.0);
    _drawCoralBranch(
      canvas,
      Offset(size.width * 0.14, size.height * 0.92),
      paint,
      stroke,
      scale: 0.7,
    );

    // Small fish silhouettes
    final fish = Paint()..color = LandingColors.teal.withValues(alpha: 0.06);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.22, size.height * 0.78),
        width: 18,
        height: 8,
      ),
      fish,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.28, size.height * 0.82),
        width: 12,
        height: 5,
      ),
      fish,
    );
  }

  void _drawCoralBranch(
    Canvas canvas,
    Offset base,
    Paint fill,
    Paint stroke, {
    required double scale,
  }) {
    final path = Path();
    path.moveTo(base.dx, base.dy);
    path.lineTo(base.dx + 8 * scale, base.dy - 42 * scale);
    path.lineTo(base.dx + 22 * scale, base.dy - 28 * scale);
    path.lineTo(base.dx + 14 * scale, base.dy - 58 * scale);
    path.lineTo(base.dx + 32 * scale, base.dy - 48 * scale);
    path.lineTo(base.dx + 26 * scale, base.dy - 72 * scale);
    path.lineTo(base.dx + 40 * scale, base.dy - 55 * scale);
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
