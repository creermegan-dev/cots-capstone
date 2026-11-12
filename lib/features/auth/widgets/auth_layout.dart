import 'package:flutter/material.dart';
import '../../../core/cots_theme.dart';

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
  static const inputFill = CotsUi.secondarySurface;
  static const inputBorder = CotsUi.divider;
  static const focusTeal = CotsUi.primary;
  static const gradientStart = Color(0xFF00B8B0);
  static const gradientEnd = Color(0xFF007A87);
  static const titleNavy = CotsUi.text;
  static const subtitleGray = CotsUi.secondaryText;

  static const double fieldHeight = 52;
  static const double fieldRadius = CotsUi.controlRadius;
  static const double cardRadius = 20;
  static const double cardPaddingDesktop = 32;
  static const double buttonHeight = 52;
  static const double buttonRadius = CotsUi.controlRadius;

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.025),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ];
}
