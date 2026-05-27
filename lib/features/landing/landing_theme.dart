import 'package:flutter/material.dart';

/// Dark marine palette for the public landing page.
abstract final class LandingColors {
  static const background = Color(0xFF031326);
  static const backgroundDeep = Color(0xFF020B18);
  static const teal = Color(0xFF00D1C1);
  static const cyan = Color(0xFF2EC4C4);
  static const tealGlow = Color(0x6600D1C1);
  static const textPrimary = Colors.white;
  static const textMuted = Color(0xFF8BA4B4);
  static const divider = Color(0xFF1A3344);
  static const glassFill = Color(0x14FFFFFF);
  static const glassBorder = Color(0x22FFFFFF);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, cyan],
  );

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF041E38), background, backgroundDeep],
    stops: [0.0, 0.45, 1.0],
  );

  static const buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF00B8A9), teal, cyan],
  );
}
