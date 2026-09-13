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
  const AdminDashboardScreen({super.key, this.onOpenMapMonitoring});

  final VoidCallback? onOpenMapMonitoring;

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
        content: Text('Dashboard refreshed — recent submissions load from Firestore.'),
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
              _mapAndCharts(wide, widget.onOpenMapMonitoring),
              const SizedBox(height: 20),
              _bottomGrid(wide),
              const SizedBox(height: 20),
              _reportsSummaryCard(),
              const SizedBox(height: 20),
              Text(
                'Quick Access Cards',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.headerTitle,
                ),
              ),
              const SizedBox(height: 12),
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
        title: 'Total Monitoring Zones',
        value: '12',
        subtitle: 'All reef monitoring zones',
        icon: Icons.map_outlined,
        accentColor: AdminColors.statBlue,
      ),
      const AdminStatCard(
        title: 'Moderate/High Risk Zones',
        value: '4',
        subtitle: 'Elevated infestation levels',
        icon: Icons.warning_amber_rounded,
        accentColor: AdminColors.statRed,
      ),
      const AdminStatCard(
        title: 'Zones Requiring Intervention',
        value: '3',
        subtitle: 'Assigned for removal action',
        icon: Icons.medical_services_outlined,
        accentColor: AdminColors.statYellow,
      ),
      const AdminStatCard(
        title: 'Cleared Zones',
        value: '5',
        subtitle: 'No active COTS detected',
        icon: Icons.check_circle_outline_rounded,
        accentColor: AdminColors.statGreen,
      ),
      const AdminStatCard(
        title: 'Total Validated COTS Detections',
        value: '186',
        subtitle: 'Expert-validated detections',
        icon: Icons.verified_rounded,
        accentColor: AdminColors.statPurple,
      ),
      const AdminStatCard(
        title: 'Pending Expert Validation',
        value: '27',
        subtitle: 'Awaiting expert review',
        icon: Icons.pending_actions_outlined,
        accentColor: Color(0xFFE67E22),
      ),
    ];

    if (maxWidth < 700) {
      return Column(
        children: cards
            .map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c))
            .toList(),
      );
    }

    Widget rowOfThree(List<Widget> trio) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < trio.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == trio.length - 1 ? 0 : 12),
                child: trio[i],
              ),
            ),
        ],
      );
    }

    return Column(
      children: [
        rowOfThree(cards.sublist(0, 3)),
        const SizedBox(height: 12),
        rowOfThree(cards.sublist(3, 6)),
      ],
    );
  }

  static Widget _reportsSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assessment_outlined, color: AdminColors.statBlue, size: 22),
              SizedBox(width: 10),
              Text(
                'Reports Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.headerTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: const [
              _ReportSummaryChip(label: 'Monthly Reports', value: '12'),
              _ReportSummaryChip(label: 'Detection Reports', value: '56'),
              _ReportSummaryChip(label: 'Outbreak Alerts', value: '9'),
              _ReportSummaryChip(label: 'Exported This Month', value: '7'),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _mapAndCharts(bool wide, VoidCallback? onOpenMapMonitoring) {
    final map = ZoneMapOverviewCard(onExpandMap: onOpenMapMonitoring);
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

class _ReportSummaryChip extends StatelessWidget {
  const _ReportSummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AdminColors.statBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminColors.statBlue.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AdminColors.statBlue,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AdminColors.muted.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}
