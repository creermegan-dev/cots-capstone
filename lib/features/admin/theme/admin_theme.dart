import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Admin panel color palette (separate from user-facing [cots_colors]).
abstract final class AdminColors {
  static const Color sidebarTop = Color(0xFF0F2744);
  static const Color sidebarBottom = Color(0xFF143D52);
  static const Color sidebarAccentGlow = Color(0x3318C6D9);
  static const Color navActive = Color(0xFF2563EB);
  static const Color navText = Color(0xFFB8C5D6);
  static const Color navTextActive = Colors.white;
  static const Color contentBg = Color(0xFFF3F5F8);
  static const Color cardWhite = Colors.white;
  static const Color headerTitle = Color(0xFF102A43);
  static const Color muted = Color(0xFF627D98);

  static const Color statBlue = Color(0xFF2563EB);
  static const Color statRed = Color(0xFFE53935);
  static const Color statYellow = Color(0xFFF9A825);
  static const Color statGreen = Color(0xFF43A047);
  static const Color statPurple = Color(0xFF7E57C2);

  static const Color zoneActive = Color(0xCCFF5252);
  static const Color zoneScheduled = Color(0xCCFFCA28);
  static const Color zoneCleared = Color(0xCC66BB6A);
}

/// Shared **date range** chip, **Refresh** chip, and list timestamp typography so admin pages stay aligned.
abstract final class AdminDateTimeTokens {
  AdminDateTimeTokens._();

  /// Rolling last-7-days label for date-range controls (always current).
  static String get currentDateRangeLabel => rollingWeekRangeLabel();

  static String rollingWeekRangeLabel({DateTime? end}) {
    final anchor = end ?? DateTime.now();
    final start = anchor.subtract(const Duration(days: 6));
    final sameYear = start.year == anchor.year;
    if (sameYear) {
      return '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d, yyyy').format(anchor)}';
    }
    return '${DateFormat('MMM d, yyyy').format(start)} – ${DateFormat('MMM d, yyyy').format(anchor)}';
  }

  /// Current date/time for admin headers and footers.
  static String liveDateTimeLabel({DateTime? when}) =>
      DateFormat('MMM d, yyyy · h:mm:ss a').format(when ?? DateTime.now());

  static const Color _outlineBorder = Color(0xFFE2E8F0);

  /// Text inside the pill-shaped **date range** control.
  static const TextStyle dateRangeChipTextStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: Color(0xFF334155),
    decoration: TextDecoration.none,
  );

  /// **Refresh** label (same metrics as [dateRangeChipTextStyle] for vertical alignment).
  static const TextStyle refreshChipTextStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AdminColors.headerTitle,
    decoration: TextDecoration.none,
  );

  /// Timestamps in tables and dense detail rows (`MMM d, y hh:mm a`).
  static TextStyle inlineDateTimeTextStyle({bool secondary = false}) =>
      TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        height: 1.2,
        decoration: TextDecoration.none,
        color: secondary
            ? AdminColors.muted.withValues(alpha: 0.95)
            : AdminColors.headerTitle.withValues(alpha: 0.88),
      );

  static ButtonStyle dateRangeOutlinedButtonStyle() => OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF64748B),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: const StadiumBorder(),
        side: const BorderSide(color: _outlineBorder),
      );

  static ButtonStyle refreshOutlinedButtonStyle() => OutlinedButton.styleFrom(
        foregroundColor: AdminColors.headerTitle,
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: _outlineBorder),
      );

  static Widget dateChipIcon(
          {IconData icon = Icons.calendar_today_outlined, double size = 18}) =>
      Icon(
        icon,
        size: size,
        color: AdminColors.muted.withValues(alpha: 0.9),
      );

  static const Icon refreshIcon = Icon(
    Icons.refresh_rounded,
    size: 20,
    color: AdminColors.headerTitle,
  );
}

ThemeData adminTheme(BuildContext context) {
  final base = Theme.of(context);
  final inter = GoogleFonts.interTextTheme(base.textTheme);
  final primaryInter = GoogleFonts.interTextTheme(base.primaryTextTheme);
  return Theme.of(context).copyWith(
    textTheme: inter.apply(decoration: TextDecoration.none),
    primaryTextTheme: primaryInter.apply(decoration: TextDecoration.none),
    scaffoldBackgroundColor: AdminColors.contentBg,
  );
}

/// Admin shell + default body text: no underlines from merged Material styles,
/// [RichText] defaults, or browser spellcheck decoration on web.
Widget adminThemedSubtree(BuildContext context, {required Widget child}) {
  return Theme(
    data: adminTheme(context),
    child: DefaultTextStyle.merge(
      style: const TextStyle(
        decoration: TextDecoration.none,
        decorationThickness: 0,
      ),
      child: child,
    ),
  );
}
