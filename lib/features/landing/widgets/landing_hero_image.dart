import 'package:flutter/material.dart';

import '../landing_theme.dart';

/// Hero reef photo with a feathered blend into the page background.
class LandingHeroImage extends StatelessWidget {
  const LandingHeroImage({
    super.key,
    this.borderRadius,
    this.fullBleed = false,
  });

  final BorderRadius? borderRadius;
  final bool fullBleed;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/landing_hero.png',
      fit: BoxFit.cover,
      alignment: fullBleed ? Alignment.centerRight : Alignment.center,
      errorBuilder: (_, __, ___) => const _HeroFallback(),
    );

    final overlays = <Widget>[
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: LandingColors.heroHorizontalBlend),
        ),
      ),
      if (!fullBleed)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: LandingColors.heroCardEdgeBlend),
          ),
        ),
      if (!fullBleed)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  LandingColors.backgroundTop.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.22],
              ),
            ),
          ),
        ),
    ];

    final stack = Stack(
      fit: StackFit.expand,
      children: [image, ...overlays],
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: stack);
    }
    return stack;
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
