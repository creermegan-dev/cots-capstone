import 'package:flutter/material.dart';

import '../../../widgets/monitoring_analytics_panel.dart';
import '../../../widgets/monitoring_record_map.dart';
import '../layout/admin_breakpoints.dart';
import '../theme/admin_theme.dart';
import '../widgets/recent_submissions_table_card.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key, this.onOpenMapMonitoring});
  final VoidCallback? onOpenMapMonitoring;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final padding = AdminBreakpoints.pagePadding(constraints.maxWidth);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(padding.left, 22, padding.right, 28),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Dashboard Overview',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AdminColors.headerTitle)),
            const SizedBox(height: 6),
            const Text('Live summaries from saved monitoring records.',
                style: TextStyle(color: AdminColors.muted)),
            const SizedBox(height: 18),
            MonitoringAnalyticsPanel(
                trailingBuilder: (context, records) => Column(children: [
                      const SizedBox(height: 18),
                      MonitoringRecordMap(
                          records: records, onExpandMap: onOpenMapMonitoring),
                      const SizedBox(height: 18),
                      const RecentSubmissionsTableCard(),
                    ])),
          ]),
        );
      });
}
