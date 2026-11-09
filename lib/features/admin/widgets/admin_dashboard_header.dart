import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/admin_theme.dart';

/// Uniform, clean, and professional page header used across all Admin screens.
class AdminDashboardHeader extends StatelessWidget {
  const AdminDashboardHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onRefreshTap,
    this.breadcrumb,
    this.leading,
    this.showRefreshButton = true,
    this.trailingExtra,
    this.showDateChip = false,
    this.showDateTime = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onRefreshTap;

  /// Optional trail (e.g. `Dashboard › Zones`); styled small and muted.
  final String? breadcrumb;

  /// Optional control shown before the title column (e.g. back on detail routes).
  final Widget? leading;

  /// When false or when [onRefreshTap] is null, the Refresh button is hidden.
  final bool showRefreshButton;

  /// Optional widget after refresh button (e.g. primary CTA like "Export PDF", "Add User").
  final Widget? trailingExtra;

  /// Optional date filter chip (default false to keep pages clean and uncluttered).
  final bool showDateChip;

  /// In the dashboard, displays the live formatted date and time.
  final bool showDateTime;

  static const double _narrowActionsBreakpoint = 720;

  TextStyle get _subtitleStyle => TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: AdminColors.muted.withValues(alpha: 0.95),
        height: 1.35,
        decoration: TextDecoration.none,
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < _narrowActionsBreakpoint;
        final actions = _actions(context);

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AdminColors.headerTitle,
                letterSpacing: -0.4,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 4),
            if (breadcrumb != null) ...[
              Text(
                breadcrumb!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AdminColors.muted.withValues(alpha: 0.88),
                  height: 1.25,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(subtitle, style: _subtitleStyle),
          ],
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (leading != null) ...[
                Align(alignment: Alignment.centerLeft, child: leading!),
                const SizedBox(height: 8),
              ],
              titleBlock,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                ),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: leading!,
              ),
            ],
            Expanded(child: titleBlock),
            if (actions.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: actions,
              ),
          ],
        );
      },
    );
  }

  List<Widget> _actions(BuildContext context) {
    final list = <Widget>[];

    if (showDateTime) {
      final now = DateTime.now();
      list.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: const Border.fromBorderSide(
              BorderSide(color: Color(0xFFDCE6EB)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.access_time_rounded,
                  size: 16, color: Color(0xFF008D94)),
              const SizedBox(width: 8),
              Text(
                DateFormat('MMM d, yyyy  •  h:mm a').format(now),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AdminColors.headerTitle,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (showDateChip) {
      if (list.isNotEmpty) list.add(const SizedBox(width: 8));
      list.add(
        OutlinedButton.icon(
          onPressed: () {},
          icon: AdminDateTimeTokens.dateChipIcon(),
          label: Text(AdminDateTimeTokens.currentDateRangeLabel,
              style: AdminDateTimeTokens.dateRangeChipTextStyle),
          style: AdminDateTimeTokens.dateRangeOutlinedButtonStyle(),
        ),
      );
    }

    if (showRefreshButton && onRefreshTap != null) {
      if (list.isNotEmpty) list.add(const SizedBox(width: 8));
      list.add(
        OutlinedButton.icon(
          onPressed: onRefreshTap,
          icon: AdminDateTimeTokens.refreshIcon,
          label: const Text('Refresh',
              style: AdminDateTimeTokens.refreshChipTextStyle),
          style: AdminDateTimeTokens.refreshOutlinedButtonStyle(),
        ),
      );
    }

    if (trailingExtra != null) {
      if (list.isNotEmpty) list.add(const SizedBox(width: 8));
      list.add(trailingExtra!);
    }

    return list;
  }
}
