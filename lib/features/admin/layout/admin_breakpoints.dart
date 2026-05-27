import 'package:flutter/material.dart';

/// Shared layout breakpoints for the entire admin panel.
abstract final class AdminBreakpoints {
  /// Below this width: hamburger + [Drawer], no permanent sidebar.
  static const double mobile = 768;

  /// From this width: permanent sidebar (full or compact).
  static const double tablet = 768;

  /// From this width: full-width sidebar by default (collapsible to rail).
  static const double desktop = 1024;

  /// Shell / dashboard “wide” content (two-column charts, etc.).
  static const double contentWide = 1100;

  static double widthOf(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isMobileWidth(double w) => w < mobile;
  static bool isTabletWidth(double w) => w >= mobile && w < desktop;
  static bool isDesktopWidth(double w) => w >= desktop;

  static bool isMobile(BuildContext context) => isMobileWidth(widthOf(context));
  static bool isTablet(BuildContext context) => isTabletWidth(widthOf(context));
  static bool isDesktop(BuildContext context) => isDesktopWidth(widthOf(context));

  /// Horizontal padding for scrollable admin pages.
  static EdgeInsets pagePadding(double w) {
    if (w < mobile) return const EdgeInsets.fromLTRB(14, 16, 14, 24);
    if (w < desktop) return const EdgeInsets.fromLTRB(18, 20, 18, 26);
    return const EdgeInsets.fromLTRB(24, 22, 24, 28);
  }
}
