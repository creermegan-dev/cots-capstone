import 'package:flutter/material.dart';

/// Landing palette — clean marine SaaS (matches login / signup).
abstract final class LandingColors {
  static const background = Color(0xFFFFFFFF);
  static const backgroundTop = Color(0xFFF8FCFD);
  static const teal = Color(0xFF00B8B0);
  static const cyan = Color(0xFF007A87);
  static const textPrimary = Color(0xFF0F2D3D);
  static const textMuted = Color(0xFF5C7A89);
  static const divider = Color(0xFFDCE7EC);
  static const badgeFill = Color(0xFFE8F7F6);
  static const badgeBorder = Color(0xFFB8E5E2);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, cyan],
  );

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [backgroundTop, background],
  );

  /// Horizontal fade that blends the hero photo into [backgroundTop] / page bg.
  static const heroHorizontalBlend = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      backgroundTop,
      backgroundTop,
      Color(0xF2F8FCFD),
      Color(0xD9F8FCFD),
      Color(0xA6F8FCFD),
      Color(0x66F8FCFD),
      Color(0x33F8FCFD),
      Color(0x14F8FCFD),
      Color(0x00F8FCFD),
    ],
    stops: [0.0, 0.30, 0.38, 0.44, 0.50, 0.56, 0.62, 0.68, 0.76],
  );

  /// Softens hero edges on mobile card layout.
  static const heroCardEdgeBlend = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xE6F8FCFD),
      Color(0x00F8FCFD),
      Color(0x00F8FCFD),
      Color(0xCCF8FCFD),
    ],
    stops: [0.0, 0.12, 0.88, 1.0],
  );

  static const buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF00B8B0), Color(0xFF007A87)],
  );
}
