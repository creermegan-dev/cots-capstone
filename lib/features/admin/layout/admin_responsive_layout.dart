import 'package:flutter/material.dart';

import 'admin_breakpoints.dart';

/// Ternary layout bucket for admin UI.
enum AdminLayoutSize {
  mobile,
  tablet,
  desktop,
}

/// Rebuilds when width crosses [AdminBreakpoints] thresholds.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({super.key, required this.builder});

  final Widget Function(BuildContext context, AdminLayoutSize size, double width) builder;

  static AdminLayoutSize sizeForWidth(double w) {
    if (AdminBreakpoints.isMobileWidth(w)) return AdminLayoutSize.mobile;
    if (AdminBreakpoints.isTabletWidth(w)) return AdminLayoutSize.tablet;
    return AdminLayoutSize.desktop;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return builder(context, sizeForWidth(w), w);
      },
    );
  }
}
