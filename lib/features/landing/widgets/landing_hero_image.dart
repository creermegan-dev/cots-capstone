import 'package:flutter/material.dart';

import '../landing_theme.dart';

/// Hero coral card with rounded corners and soft bottom ambient blend.
class LandingHeroImage extends StatelessWidget {
  const LandingHeroImage({
    super.key,
    this.borderRadius,
    this.fullBleed = false,
  });

  final BorderRadius? borderRadius;
  final bool fullBleed;

  static const String assetPath = 'assets/images/landing_coral.jpg';

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(36);

    return Container(
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF104E5B).withValues(alpha: 0.16),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              assetPath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const _HeroFallback(),
            ),
            // Soft atmospheric mist at the bottom of the card
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      const Color(0xFF5FCBC0).withValues(alpha: 0.20),
                      const Color(0xFF47C4B8).withValues(alpha: 0.55),
                    ],
                    stops: const [0.0, 0.65, 0.88, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8F4F6), Color(0xFFB8DDE5)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.waves_rounded, color: LandingColors.teal, size: 72),
      ),
    );
  }
}
