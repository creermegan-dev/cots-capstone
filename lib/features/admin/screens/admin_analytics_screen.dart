import 'package:flutter/material.dart';

import '../../../widgets/monitoring_analytics_panel.dart';
import '../layout/admin_breakpoints.dart';
import '../widgets/admin_dashboard_header.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminDashboardHeader(
                title: 'Analytics',
                subtitle:
                    'Live monitoring records, AI detections, and Expert decisions.',
                showRefreshButton: true,
                onRefreshTap: _onRefresh,
              ),
              const SizedBox(height: 18),
              const MonitoringAnalyticsPanel(useSiteTerminology: true),
            ],
          ),
        );
      });
}
