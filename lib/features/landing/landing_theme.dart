import 'package:flutter/material.dart';

/// Landing palette — clean marine SaaS matching reference mockup.
abstract final class LandingColors {
  static const background = Color(0xFFF5FBFC);
  static const backgroundTop = Color(0xFFF5FBFC);
  static const backgroundBottom = Color(0xFFEDF6F8);
  static const teal = Color(0xFF00B8B0);
  static const cyan = Color(0xFF008D94);
  static const buttonTeal = Color(0xFF008D94);
  static const textPrimary = Color(0xFF123244);
  static const textMuted = Color(0xFF5A6E7F);
  static const divider = Color(0xFFDCE7EC);
  static const badgeFill = Color(0xFFE8F7F6);
  static const badgeBorder = Color(0xFFB8E5E2);
  static const logoCircleBg = Color(0xFFE0F7F5);
  static const avatarBg = Color(0xFF008D94);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, cyan],
  );

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF5FBFC), Color(0xFFEDF6F8)],
  );

  /// Atmospheric underwater teal/mint glow rising from the bottom.
  static const bottomMistGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00FFFFFF),
      Color(0x2285E5D8),
      Color(0x885ECBC1),
      Color(0xFF47C4B8),
    ],
    stops: [0.0, 0.40, 0.78, 1.0],
  );

  static const buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF008D94), Color(0xFF007E84)],
  );

  /// Horizontal fade fallback
  static const heroHorizontalBlend = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0x00FFFFFF),
    ],
  );

  /// Card edge blend
  static const heroCardEdgeBlend = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0x8047C4B8),
    ],
  );
}
