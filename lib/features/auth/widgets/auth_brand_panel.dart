import 'package:flutter/material.dart';

import 'auth_layout.dart';
import 'cots_auth_logo_badge.dart';

/// Left brand column for desktop auth (40% width).
class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key});

  static const _features = [
    'Machine Learning',
    'GIS Mapping',
    'Expert Validation',
    'Reef Conservation',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _BrandLogo(size: 56),
          const SizedBox(height: 28),
          const Text(
            'COTS Monitor',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AuthTokens.titleNavy,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Machine Learning-Based Crown-of-Thorns Starfish Monitoring Platform',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AuthTokens.subtitleGray.withValues(alpha: 0.95),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 32),
          for (final f in _features) ...[
            _FeatureRow(label: f),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 36),
          const _CoralIllustration(),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AuthTokens.focusTeal.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 14,
            color: AuthTokens.focusTeal,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AuthTokens.titleNavy,
          ),
        ),
      ],
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8F7FA), Colors.white],
        ),
        border: Border.all(color: AuthTokens.focusTeal.withValues(alpha: 0.25)),
        boxShadow: AuthTokens.cardShadow,
      ),
      child: ClipOval(
        child: Image.asset(
          kCotsLogoAsset,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _CoralIllustration extends StatelessWidget {
  const _CoralIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: CustomPaint(
        painter: _CoralLinesPainter(),
        size: const Size(double.infinity, 120),
      ),
    );
  }
}

class _CoralLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final paint = Paint()
      ..color = AuthTokens.focusTeal.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Abstract coral branches
    final base = Offset(w * 0.08, size.height * 0.85);
    canvas.drawLine(base, Offset(w * 0.12, size.height * 0.35), paint);
    canvas.drawLine(
      Offset(w * 0.12, size.height * 0.55),
      Offset(w * 0.28, size.height * 0.4),
      paint,
    );
    canvas.drawLine(
      Offset(w * 0.12, size.height * 0.45),
      Offset(w * 0.22, size.height * 0.25),
      paint,
    );

    final blob = Paint()
      ..color = AuthTokens.focusTeal.withValues(alpha: 0.08);
    canvas.drawCircle(Offset(w * 0.55, size.height * 0.5), 36, blob);
    canvas.drawCircle(Offset(w * 0.72, size.height * 0.65), 24, blob);

    // Soft wave line
    final wave = Path()
      ..moveTo(0, size.height * 0.92)
      ..quadraticBezierTo(w * 0.35, size.height * 0.78, w * 0.7, size.height * 0.9)
      ..quadraticBezierTo(w * 0.9, size.height * 0.98, w, size.height * 0.88);
    canvas.drawPath(wave, paint..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
