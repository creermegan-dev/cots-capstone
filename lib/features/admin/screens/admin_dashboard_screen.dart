import 'package:flutter/material.dart';

import '../layout/admin_breakpoints.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dashboard_header.dart';
import '../widgets/admin_stat_card.dart';
import '../widgets/admin_summary_footer_cards.dart';
import '../widgets/cots_status_donut_card.dart';
import '../widgets/detections_line_chart_card.dart';
import '../widgets/outbreak_alerts_panel.dart';
import '../widgets/recent_submissions_table_card.dart';
import '../widgets/zone_map_overview_card.dart';

/// Main analytics dashboard (mock data).
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _refreshGeneration = 0;

  void _onDashboardRefresh() {
    setState(() => _refreshGeneration++);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Dashboard data refreshed (demo).'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final wide = w >= AdminBreakpoints.contentWide;
        final basePad = AdminBreakpoints.pagePadding(w);
        final pad = EdgeInsets.fromLTRB(basePad.left, 22, basePad.right, 22);

        return SingleChildScrollView(
          padding: pad,
          child: Column(
            key: ValueKey<int>(_refreshGeneration),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminDashboardHeader(
                title: 'Dashboard Overview',
                subtitle:
                    'Welcome back, Admin! Here\'s what\'s happening with the COTS monitoring system.',
                onRefreshTap: _onDashboardRefresh,
              ),
              const SizedBox(height: 22),
              _statsRow(context, constraints.maxWidth),
              const SizedBox(height: 20),
              _mapAndCharts(wide),
              const SizedBox(height: 20),
              _bottomGrid(wide),
              const SizedBox(height: 20),
              const AdminSummaryFooterCards(),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  static Widget _statsRow(BuildContext context, double maxWidth) {
    final cards = [
      const AdminStatCard(
        title: 'Total Zones',
        value: '12',
        subtitle: 'All monitoring zones',
        icon: Icons.map_outlined,
        accentColor: AdminColors.statBlue,
      ),
      const AdminStatCard(
        title: 'Active Zones (Outbreak)',
        value: '4',
        subtitle: 'Require immediate action',
        icon: Icons.emergency_outlined,
        accentColor: AdminColors.statRed,
      ),
      const AdminStatCard(
        title: 'Scheduled Zones',
        value: '3',
        subtitle: 'Planned for removal',
        icon: Icons.schedule_rounded,
        accentColor: AdminColors.statYellow,
      ),
      const AdminStatCard(
        title: 'Cleared Zones',
        value: '5',
        subtitle: 'No COTS detected',
        icon: Icons.check_circle_outline_rounded,
        accentColor: AdminColors.statGreen,
      ),
      const AdminStatCard(
        title: 'Total COTS Detected',
        value: '248',
        subtitle: 'Across all zones',
        icon: Icons.pest_control_outlined,
        accentColor: AdminColors.statPurple,
      ),
    ];

    if (maxWidth < 640) {
      return Column(
        children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList(),
      );
    }
    if (maxWidth < 1100) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards.map((c) => SizedBox(width: (maxWidth - 28 - 12) / 2, child: c)).toList(),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cards.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == cards.length - 1 ? 0 : 12),
              child: cards[i],
            ),
          ),
      ],
    );
  }

  static Widget _mapAndCharts(bool wide) {
    const map = ZoneMapOverviewCard();
    const charts = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetectionsLineChartCard(),
        SizedBox(height: 16),
        CotsStatusDonutCard(),
      ],
    );

    if (wide) {
      // Do not use [IntrinsicHeight] here: inside [SingleChildScrollView] height is
      // unbounded and IntrinsicHeight breaks layout / hit-testing (e.g. web).
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 58, child: map),
          const SizedBox(width: 18),
          Expanded(flex: 42, child: charts),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        map,
        const SizedBox(height: 18),
        charts,
      ],
    );
  }

  static Widget _bottomGrid(bool wide) {
    const table = RecentSubmissionsTableCard();
    const alerts = OutbreakAlertsPanel();

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 55, child: table),
          const SizedBox(width: 18),
          Expanded(flex: 45, child: alerts),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        table,
        const SizedBox(height: 18),
        alerts,
      ],
    );
  }
}
