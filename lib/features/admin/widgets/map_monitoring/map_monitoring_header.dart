import 'package:flutter/material.dart';

import '../../theme/admin_theme.dart';
import 'map_monitoring_data.dart';

class MapMonitoringHeader extends StatelessWidget {
  const MapMonitoringHeader({
    super.key,
    required this.onDateRangeTap,
    required this.onRefreshTap,
  });

  final VoidCallback onDateRangeTap;
  final VoidCallback onRefreshTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 720;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (narrow) ...[
              const Text(
                'Map Monitoring',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.headerTitle,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                MapMonitoringMock.subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: AdminColors.muted.withValues(alpha: 0.95),
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.start,
                children: _actions(),
              ),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Map Monitoring',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AdminColors.headerTitle,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          MapMonitoringMock.subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: AdminColors.muted.withValues(alpha: 0.95),
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._actions(),
                ],
              ),
          ],
        );
      },
    );
  }

  List<Widget> _actions() {
    return [
      OutlinedButton.icon(
        onPressed: onDateRangeTap,
        icon: AdminDateTimeTokens.dateChipIcon(),
        label: const Text(AdminDateTimeTokens.demoDateRangeLabel, style: AdminDateTimeTokens.dateRangeChipTextStyle),
        style: AdminDateTimeTokens.dateRangeOutlinedButtonStyle(),
      ),
      const SizedBox(width: 10),
      OutlinedButton.icon(
        onPressed: onRefreshTap,
        icon: AdminDateTimeTokens.refreshIcon,
        label: const Text('Refresh', style: AdminDateTimeTokens.refreshChipTextStyle),
        style: AdminDateTimeTokens.refreshOutlinedButtonStyle(),
      ),
    ];
  }
}
