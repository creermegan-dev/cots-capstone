import 'package:flutter/material.dart';

import '../../../core/supabase_config.dart';
import '../../../widgets/site_levels_row.dart';
import '../../../widgets/monitoring_analytics_panel.dart';
import '../../../widgets/monitoring_record_map.dart';
import '../layout/admin_breakpoints.dart';
import '../widgets/admin_dashboard_header.dart';
import '../widgets/recent_submissions_table_card.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, this.onOpenMapMonitoring});
  final VoidCallback? onOpenMapMonitoring;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _refreshGeneration = 0;

  void _onRefresh() {
    setState(() => _refreshGeneration++);
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final padding = AdminBreakpoints.pagePadding(constraints.maxWidth);
        return SingleChildScrollView(
          key: ValueKey<int>(_refreshGeneration),
          padding: EdgeInsets.fromLTRB(padding.left, 22, padding.right, 28),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AdminDashboardHeader(
              title: 'Dashboard Overview',
              subtitle: 'Live summaries from saved monitoring records.',
              showDateTime: true,
              showRefreshButton: true,
              onRefreshTap: _onRefresh,
            ),
            const SizedBox(height: 18),
            // 2026-11-08: each site's level this month, High first.
            if (SupabaseConfig.isConfigured) ...[
              const SiteLevelsRow(),
              const SizedBox(height: 18),
            ],
            MonitoringAnalyticsPanel(
                dashboardLayout: true,
                useSiteTerminology: true,
                showHeaderFilters: false,
                trailingBuilder: (context, records) => Column(children: [
                      const SizedBox(height: 18),
                      MonitoringRecordMap(
                          records: records, onExpandMap: widget.onOpenMapMonitoring),
                      const SizedBox(height: 18),
                      const RecentSubmissionsTableCard(),
                    ])),
          ]),
        );
      });
}
