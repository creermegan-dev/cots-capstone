import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../landing_theme.dart';

/// Futuristic scanning rings overlaid on the hero reef image.
class LandingScanHud extends StatefulWidget {
  const LandingScanHud({super.key});

  @override
  State<LandingScanHud> createState() => _LandingScanHudState();
}

class _LandingScanHudState extends State<LandingScanHud>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _ScanHudPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ScanHudPainter extends CustomPainter {
  _ScanHudPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.52, size.height * 0.48);
    final baseR = math.min(size.width, size.height) * 0.22;

    void ring(double scale, double alpha, {double dash = 0, double rot = 0}) {
      final r = baseR * scale;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = LandingColors.teal.withValues(alpha: alpha);

      if (dash > 0) {
        paint.shader = null;
        _drawDashedCircle(canvas, center, r, paint, dashLength: dash, rot: rot);
      } else {
        canvas.drawCircle(center, r, paint);
      }
    }

    // Glow core
    canvas.drawCircle(
      center,
      baseR * 0.35,
      Paint()
        ..shader = RadialGradient(
          colors: [
            LandingColors.teal.withValues(alpha: 0.35),
            LandingColors.teal.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: baseR * 0.5)),
    );

    ring(0.55, 0.55);
    ring(0.78, 0.35, dash: 10, rot: progress * math.pi * 2);
    ring(1.0, 0.25, dash: 14, rot: -progress * math.pi * 1.5);

    // Crosshair ticks
    final tickPaint = Paint()
      ..color = LandingColors.cyan.withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 8; i++) {
      final angle = (i / 8) * math.pi * 2 + progress * 0.4;
      final inner = baseR * 1.05;
      final outer = baseR * 1.12;
      canvas.drawLine(
        center + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        center + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
        tickPaint,
      );
    }

    // Bracket corners
    _drawBracket(canvas, center, baseR * 1.18, LandingColors.teal.withValues(alpha: 0.6));
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint, {
    required double dashLength,
    required double rot,
  }) {
    const segments = 64;
    for (var i = 0; i < segments; i++) {
      if (i.isOdd) continue;
      final a1 = rot + (i / segments) * math.pi * 2;
      final a2 = rot + ((i + 1) / segments) * math.pi * 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        a1,
        a2 - a1,
        false,
        paint..strokeWidth = 1.4,
      );
    }
  }

  void _drawBracket(Canvas canvas, Offset c, double r, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 18.0;
    const gap = 6.0;

    void corner(double dx, double dy, bool flipH, bool flipV) {
      final ox = c.dx + dx * (r + gap);
      final oy = c.dy + dy * (r + gap);
      final hx = flipH ? -1.0 : 1.0;
      final vy = flipV ? -1.0 : 1.0;
      canvas.drawLine(Offset(ox, oy), Offset(ox + hx * len, oy), p);
      canvas.drawLine(Offset(ox, oy), Offset(ox, oy + vy * len), p);
    }

    corner(-1, -1, true, true);
    corner(1, -1, false, true);
    corner(-1, 1, true, false);
    corner(1, 1, false, false);
  }

  @override
  bool shouldRepaint(covariant _ScanHudPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
