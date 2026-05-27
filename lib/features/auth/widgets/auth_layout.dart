import 'package:flutter/material.dart';

/// Auth responsive breakpoints (per product spec).
abstract final class AuthBreakpoints {
  static const double desktop = 1200;
  static const double tablet = 768;

  static const double pageMaxWidth = 1100;
  static const double cardMaxWidth = 480;
}

enum AuthLayoutMode { mobile, tablet, desktop }

AuthLayoutMode authLayoutModeOf(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= AuthBreakpoints.desktop) return AuthLayoutMode.desktop;
  if (w >= AuthBreakpoints.tablet) return AuthLayoutMode.tablet;
  return AuthLayoutMode.mobile;
}

bool authUseDesktopFields(BuildContext context) =>
    authLayoutModeOf(context) != AuthLayoutMode.mobile;

/// Marine-inspired auth design tokens.
abstract final class AuthTokens {
  static const bgTop = Color(0xFFF5FBFC);
  static const bgBottom = Color(0xFFEDF6F8);
  static const inputFill = Color(0xFFF7FAFB);
  static const inputBorder = Color(0xFFDCE7EC);
  static const focusTeal = Color(0xFF00B8B0);
  static const gradientStart = Color(0xFF00B8B0);
  static const gradientEnd = Color(0xFF007A87);
  static const titleNavy = Color(0xFF0F2D3D);
  static const subtitleGray = Color(0xFF5C7A89);

  static const double fieldHeight = 58;
  static const double fieldRadius = 16;
  static const double cardRadius = 28;
  static const double cardPaddingDesktop = 40;
  static const double buttonHeight = 56;
  static const double buttonRadius = 18;

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
      ];
}
