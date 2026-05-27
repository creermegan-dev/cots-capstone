import 'package:flutter/material.dart';

/// Soft wavy divider at the bottom of the hero section.
class LandingBottomWave extends StatelessWidget {
  const LandingBottomWave({super.key, this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Feather the hero into the wave so the seam is invisible
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0),
                  color.withValues(alpha: 0.85),
                  color,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          CustomPaint(
            painter: _WavePainter(color: color),
            size: Size.infinite,
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(0, h * 0.45)
      ..quadraticBezierTo(w * 0.2, h * 0.15, w * 0.42, h * 0.38)
      ..quadraticBezierTo(w * 0.62, h * 0.62, w * 0.82, h * 0.28)
      ..quadraticBezierTo(w * 0.92, h * 0.12, w, h * 0.35)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.color != color;
}
