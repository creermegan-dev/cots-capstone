import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

class AdminDashboardHeader extends StatelessWidget {
  const AdminDashboardHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onRefreshTap,
    this.breadcrumb,
    this.leading,
    this.showRefreshButton = true,
    this.trailingExtra,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRefreshTap;

  /// Optional trail (e.g. `Dashboard › Zones`); styled small and muted.
  final String? breadcrumb;

  /// Optional control shown before the title column (e.g. back on detail routes).
  final Widget? leading;

  /// When false, the Refresh button is hidden (date and [trailingExtra] still show).
  final bool showRefreshButton;

  /// Optional widget after date / refresh (e.g. primary CTA like "Add New User").
  final Widget? trailingExtra;

  static const double _narrowActionsBreakpoint = 720;

  TextStyle get _subtitleStyle => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AdminColors.muted.withValues(alpha: 0.95),
        height: 1.35,
        decoration: TextDecoration.none,
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < _narrowActionsBreakpoint;
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AdminColors.headerTitle,
                letterSpacing: -0.6,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 6),
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
              const SizedBox(height: 6),
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
                const SizedBox(height: 10),
              ],
              titleBlock,
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: _actions(context),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[
              Padding(
                padding: const EdgeInsets.only(right: 4, top: 2),
                child: leading!,
              ),
            ],
            Expanded(child: titleBlock),
            ..._actions(context),
          ],
        );
      },
    );
  }

  List<Widget> _actions(BuildContext context) {
    final list = <Widget>[
      OutlinedButton.icon(
        onPressed: () {},
        icon: AdminDateTimeTokens.dateChipIcon(),
        label: Text(AdminDateTimeTokens.currentDateRangeLabel,
            style: AdminDateTimeTokens.dateRangeChipTextStyle),
        style: AdminDateTimeTokens.dateRangeOutlinedButtonStyle(),
      ),
    ];

    if (showRefreshButton) {
      list.add(const SizedBox(width: 10));
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
      list.add(const SizedBox(width: 10));
      list.add(trailingExtra!);
    }

    return list;
  }
}
