import 'dart:async';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/cots_colors.dart';
import '../../models/activity_type.dart';
import '../../models/intervention_assignment_model.dart';
import '../../models/scan_record_model.dart';
import '../../models/monitoring_analytics.dart';
import '../../widgets/monitoring_record_map.dart';
import '../../widgets/cots_loading_skeleton.dart';
import '../../providers/auth_provider.dart';
import '../../services/intervention_assignment_repository.dart';
import '../../services/scan_record_repository.dart';
import '../auth/auth_navigation.dart';
import 'cots_map_page.dart';
import 'notifications_screen.dart';
import 'profile_page.dart';
import 'records_page.dart';
import 'scan_detection_page.dart';
import 'user_analytics_overview_page.dart';
import 'user_bottom_nav.dart';
import 'user_dashboard_analytics.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.recordsStream});
  final Stream<List<ScanRecordModel>>? recordsStream;

  static const _bg = Color(0xFFF4F6F9);
  static const _horizontalPad = 16.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showSidebar = constraints.maxWidth >= 900;
        final scaffold = Scaffold(
          backgroundColor: _bg,
          extendBody: true,
          floatingActionButton: userShellScanFab(context),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: showSidebar
              ? null
              : UserBottomNavBar(
                  active: UserNavDestination.dashboard,
                  mapPageBuilder: () => const CotsMapPage(),
                  recordsPageBuilder: () => const RecordsPage(),
                  profilePageBuilder: () => const ProfilePage(),
                ),
          body: SafeArea(
            bottom: false,
            child: StreamBuilder<List<ScanRecordModel>>(
              stream: recordsStream ?? ScanRecordRepository.watchAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(_horizontalPad, 8,
                        _horizontalPad, showSidebar ? 28 : 100),
                    child: const CotsLoadingSkeleton(
                        layout: CotsSkeletonLayout.dashboard),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load dashboard data.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: kMutedGray),
                      ),
                    ),
                  );
                }

                final records = snapshot.data ?? [];
                final analytics = UserDashboardAnalytics.fromRecords(records);

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    _horizontalPad,
                    8,
                    _horizontalPad,
                    showSidebar ? 28 : 100,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DashboardHeader(analytics: analytics, records: records),
                      const _AssignedTasksSection(),
                      const SizedBox(height: 18),
                      const Text(
                        'Key Metrics',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: kTextNavy,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _MetricsGrid(analytics: analytics, records: records),
                      const SizedBox(height: 18),
                      _RecentMonitoringActivities(records: records),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, c) {
                          final wide = c.maxWidth >= 720;
                          if (wide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 11,
                                  child: _MonitoredZonesCard(records: records),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 9,
                                  child: _AnalyticsPreviewCard(
                                    analytics: analytics,
                                    onViewMore: () =>
                                        _openAnalytics(context, analytics),
                                  ),
                                ),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              _MonitoredZonesCard(records: records),
                              const SizedBox(height: 14),
                              _AnalyticsPreviewCard(
                                analytics: analytics,
                                onViewMore: () =>
                                    _openAnalytics(context, analytics),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );

        if (!showSidebar) return scaffold;

        return Row(
          children: [
            const _DiverSidebarMenu(),
            Expanded(child: scaffold),
          ],
        );
      },
    );
  }

  void _openAnalytics(BuildContext context, UserDashboardAnalytics analytics) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const UserAnalyticsOverviewPage(),
      ),
    );
  }
}

class _AssignedTasksSection extends StatelessWidget {
  const _AssignedTasksSection();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<List<InterventionAssignmentModel>>(
      stream: InterventionAssignmentRepository.watchForAssignee(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.only(top: 18),
            child: CotsLoadingSkeleton(
                layout: CotsSkeletonLayout.section,
                label: 'Loading assigned tasks'),
          );
        }
        final tasks = (snapshot.data ?? const [])
            .where((task) => !task.isCleared)
            .toList();
        if (tasks.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kPrimaryTeal.withValues(alpha: 0.22)),
              boxShadow: kSoftCardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.assignment_turned_in_outlined,
                      color: kPrimaryTeal,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Assigned Intervention Tasks',
                        style: TextStyle(
                          color: kTextNavy,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${tasks.length}',
                      style: const TextStyle(
                        color: kPrimaryTeal,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < tasks.length; i++) ...[
                  if (i > 0) const Divider(height: 20),
                  _AssignedTaskRow(task: tasks[i]),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AssignedTaskRow extends StatelessWidget {
  const _AssignedTaskRow({required this.task});

  final InterventionAssignmentModel task;

  @override
  Widget build(BuildContext context) {
    final due = task.dueAt == null
        ? 'No due date'
        : 'Due ${DateFormat('MMM d, yyyy').format(task.dueAt!)}';
    final evidenceSubmitted = task.hasEvidence;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.captureDisplayId.isNotEmpty
                    ? task.captureDisplayId
                    : task.captureId,
                style: const TextStyle(
                  color: kTextNavy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${task.zone} · $due',
                style: const TextStyle(color: kMutedGray, fontSize: 12),
              ),
              if (evidenceSubmitted)
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Text(
                    'Evidence submitted — awaiting administrator confirmation',
                    style: TextStyle(
                      color: kSuccessGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: evidenceSubmitted
              ? null
              : () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => ScanDetectionPage(
                        initialActivityType: CotsActivityType.removalActivity,
                        initialLinkedCaptureId: task.captureId,
                      ),
                    ),
                  );
                },
          icon: const Icon(Icons.photo_camera_outlined, size: 18),
          label: Text(evidenceSubmitted ? 'Submitted' : 'Submit Evidence'),
          style: FilledButton.styleFrom(backgroundColor: kPrimaryTeal),
        ),
      ],
    );
  }
}

class _DiverSidebarMenu extends StatelessWidget {
  const _DiverSidebarMenu();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0B2B3A),
      child: SizedBox(
        width: 220,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sidebar Menu',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'COTS Monitor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Diver Dashboard',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                _sideItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  selected: true,
                  onTap: () {},
                ),
                _sideItem(
                  context,
                  icon: Icons.map_outlined,
                  label: 'GIS Mapping',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const CotsMapPage()),
                  ),
                ),
                _sideItem(
                  context,
                  icon: Icons.photo_camera_outlined,
                  label: 'Upload Monitoring Data',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ScanDetectionPage(),
                    ),
                  ),
                ),
                _sideItem(
                  context,
                  icon: Icons.replay_circle_filled_outlined,
                  label: 'Follow-up',
                  onTap: () =>
                      Navigator.of(context).pushNamed(userFollowUpRoute),
                ),
                _sideItem(
                  context,
                  icon: Icons.folder_outlined,
                  label: 'Records',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const RecordsPage()),
                  ),
                ),
                _sideItem(
                  context,
                  icon: Icons.person_outline_rounded,
                  label: 'Profile / Settings',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const ProfilePage()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sideItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? kPrimaryTeal.withValues(alpha: 0.35)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color:
                          Colors.white.withValues(alpha: selected ? 1 : 0.88),
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentMonitoringActivities extends StatelessWidget {
  const _RecentMonitoringActivities({required this.records});

  final List<ScanRecordModel> records;

  @override
  Widget build(BuildContext context) {
    final recent = [...records]..sort((a, b) {
        final ad = a.submittedAt ?? a.dateTaken ?? DateTime(1970);
        final bd = b.submittedAt ?? b.dateTaken ?? DateTime(1970);
        return bd.compareTo(ad);
      });
    final items = recent.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderGray),
        boxShadow: kSoftCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Recent monitoring activities',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: kTextNavy,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              'No monitoring activities yet. Upload a GoPro image to get started.',
              style: TextStyle(
                color: kMutedGray.withValues(alpha: 0.95),
                fontSize: 13,
                height: 1.4,
              ),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 18),
              _recentActivityRow(items[i]),
            ],
        ],
      ),
    );
  }

  Widget _recentActivityRow(ScanRecordModel r) {
    final when = r.submittedAt ?? r.dateTaken;
    final whenLabel =
        when == null ? '—' : DateFormat('MMM d, yyyy · h:mm a').format(when);
    final isRemoval = CotsActivityType.isRemoval(r.activityType);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: (isRemoval ? kSuccessGreen : kPrimaryTeal)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isRemoval
                ? Icons.cleaning_services_outlined
                : Icons.photo_camera_outlined,
            size: 18,
            color: isRemoval ? kSuccessGreen : kPrimaryTeal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isRemoval ? 'Removal Evidence' : 'Monitoring Capture',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: kTextNavy,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${r.zone.isEmpty ? 'Unassigned zone' : r.zone} · '
                '${r.aiDetectedCount} COTS · ${r.userStatusLabel}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: kMutedGray.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                whenLabel,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: kMutedGray.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.analytics, required this.records});

  final UserDashboardAnalytics analytics;
  final List<ScanRecordModel> records;

  @override
  Widget build(BuildContext context) {
    final recordUpdated = analytics.lastUpdated;
    final user = context.watch<AuthProvider>().userModel;
    final name = (user?.fullName.trim().isNotEmpty == true)
        ? user!.fullName.trim().split(' ').first
        : 'Diver';

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, $name',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: kSuccessGreen,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Diver Dashboard',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: kTextNavy,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Crown-of-Thorns Starfish Monitoring',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: kMutedGray,
          ),
        ),
      ],
    );
    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'Notifications',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: const Icon(
            Icons.notifications_outlined,
            color: kTextNavy,
            size: 22,
          ),
          onPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsScreen(),
              ),
            );
          },
        ),
        IconButton(
          tooltip: 'Sign out',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: const Icon(Icons.logout_rounded, color: kTextNavy, size: 22),
          onPressed: () => confirmAndSignOut(context),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorderGray),
            boxShadow: kSoftCardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule_rounded,
                  size: 14, color: kMutedGray.withValues(alpha: 0.9)),
              const SizedBox(width: 6),
              Flexible(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current time',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: kMutedGray,
                    ),
                  ),
                  const _LiveDateTimeText(
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: kTextNavy,
                    ),
                  ),
                  if (recordUpdated != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Latest record ${DateFormat('MMM d, h:mm a').format(recordUpdated)}',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        color: kMutedGray.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ],
              )),
            ],
          ),
        ),
      ],
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 600 ||
          MediaQuery.textScalerOf(context).scale(12) > 18) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 12),
              controls,
            ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: title),
        const SizedBox(width: 12),
        Flexible(child: controls),
      ]);
    });
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.analytics, required this.records});

  final UserDashboardAnalytics analytics;
  final List<ScanRecordModel> records;

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat.decimalPattern();
    final data = MonitoringAnalytics.fromRecords(records);
    final pending = data.pending;
    final confirmed = data.accepted;
    final removed = data.removalRecords.length;
    final captures = data.captures.length;

    return LayoutBuilder(
      builder: (context, c) {
        const gap = 12.0;
        final half = (c.maxWidth - gap) / 2;
        return Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: half,
                  child: _MetricCard(
                    icon: Icons.photo_library_outlined,
                    iconColor: kAccentPurple,
                    iconBg: kAccentPurple.withValues(alpha: 0.12),
                    title: 'Total Monitoring Captures',
                    value: nf.format(captures),
                    trendPct: analytics.scansTrendPct,
                    period: analytics.periodLabel,
                    sparkline: analytics.dailyTrendValues,
                    sparkColor: kAccentPurple,
                    sparkType: _SparkType.bar,
                  ),
                ),
                const SizedBox(width: gap),
                SizedBox(
                  width: half,
                  child: _MetricCard(
                    icon: Icons.hourglass_top_rounded,
                    iconColor: const Color(0xFFE6A23C),
                    iconBg: const Color(0xFFE6A23C).withValues(alpha: 0.12),
                    title: 'Pending Validation',
                    value: '$pending',
                    trendPct: null,
                    period: analytics.periodLabel,
                    sparkline: const [],
                    sparkColor: const Color(0xFFE6A23C),
                    sparkType: _SparkType.dots,
                  ),
                ),
              ],
            ),
            const SizedBox(height: gap),
            Row(
              children: [
                SizedBox(
                  width: half,
                  child: _MetricCard(
                    icon: Icons.verified_rounded,
                    iconColor: kSuccessGreen,
                    iconBg: kSuccessGreen.withValues(alpha: 0.12),
                    title: 'Confirmed Detections',
                    value: '$confirmed',
                    trendPct: null,
                    period: analytics.periodLabel,
                    sparkline: const [],
                    sparkColor: kSuccessGreen,
                    sparkType: _SparkType.line,
                  ),
                ),
                const SizedBox(width: gap),
                SizedBox(
                  width: half,
                  child: _MetricCard(
                    icon: Icons.cleaning_services_outlined,
                    iconColor: kInfoBlue,
                    iconBg: kInfoBlue.withValues(alpha: 0.12),
                    title: 'Removal Activities',
                    value: '$removed',
                    trendPct: null,
                    period: analytics.periodLabel,
                    sparkline: const [],
                    sparkColor: kInfoBlue,
                    sparkType: _SparkType.wave,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

enum _SparkType { line, bar, dots, wave }

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.value,
    required this.period,
    required this.sparkline,
    required this.sparkColor,
    required this.sparkType,
    this.trendPct,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String value;
  final double? trendPct;
  final String period;
  final List<double> sparkline;
  final Color sparkColor;
  final _SparkType sparkType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderGray),
        boxShadow: kSoftCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const Spacer(),
              SizedBox(
                width: 72,
                height: 36,
                child: _MiniSparkline(
                  values: sparkline,
                  color: sparkColor,
                  type: sparkType,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: kMutedGray,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: kTextNavy,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (trendPct != null)
            _TrendLine(pct: trendPct!, period: period)
          else
            Text(
              'vs $period',
              style: const TextStyle(fontSize: 10, color: kMutedGray),
            ),
        ],
      ),
    );
  }
}

class _TrendLine extends StatelessWidget {
  const _TrendLine({required this.pct, required this.period});

  final double pct;
  final String period;

  @override
  Widget build(BuildContext context) {
    final up = pct >= 0;
    final color = up ? kSuccessGreen : kDangerRed;
    final sign = pct == 0 ? '' : (up ? '↑ ' : '↓ ');
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 10, height: 1.3),
        children: [
          TextSpan(
            text: '$sign${pct.abs().toStringAsFixed(1)}% ',
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
          TextSpan(
            text: 'vs $period',
            style:
                const TextStyle(color: kMutedGray, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  const _MiniSparkline({
    required this.values,
    required this.color,
    required this.type,
  });

  final List<double> values;
  final Color color;
  final _SparkType type;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();

    if (type == _SparkType.bar) {
      final max = values.reduce((a, b) => a > b ? a : b).clamp(1, 999);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (final v in values)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Container(
                width: 5,
                height: 8 + (24 * v / max),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      );
    }

    if (type == _SparkType.dots) {
      return Wrap(
        alignment: WrapAlignment.end,
        spacing: 3,
        runSpacing: 3,
        children: [
          for (final v in values)
            Container(
              width: 5 + v * 2,
              height: 5 + v * 2,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.35 + v * 0.08),
                shape: BoxShape.circle,
              ),
            ),
        ],
      );
    }

    return CustomPaint(
      size: const Size(72, 36),
      painter: _SparkPainter(
          values: values, color: color, wave: type == _SparkType.wave),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.values,
    required this.color,
    required this.wave,
  });

  final List<double> values;
  final Color color;
  final bool wave;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final max = values.reduce((a, b) => a > b ? a : b).clamp(1.0, 999.0);
    final paint = Paint()
      ..color = color
      ..strokeWidth = wave ? 2 : 2.2
      ..style = wave ? PaintingStyle.stroke : PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = ui.Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1).clamp(1, 99);
      final y = size.height - (values[i] / max) * (size.height - 4) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    if (!wave) {
      final fill = ui.Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            colors: [
              color.withValues(alpha: 0.2),
              color.withValues(alpha: 0.02)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) => true;
}

class _MonitoredZonesCard extends StatelessWidget {
  const _MonitoredZonesCard({required this.records});
  final List<ScanRecordModel> records;
  @override
  Widget build(BuildContext context) => MonitoringRecordMap(records: records);
}

class _AnalyticsPreviewCard extends StatelessWidget {
  const _AnalyticsPreviewCard({
    required this.analytics,
    required this.onViewMore,
  });

  final UserDashboardAnalytics analytics;
  final VoidCallback onViewMore;

  @override
  Widget build(BuildContext context) {
    final spots = analytics.dailyTrendSpots;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderGray),
        boxShadow: kSoftCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ANALYTICS OVERVIEW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: kMutedGray,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Last 7 days - live data',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kTextNavy,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onViewMore,
                style: TextButton.styleFrom(
                  foregroundColor: kSuccessGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View more',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 18),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.show_chart_rounded, size: 16, color: kInfoBlue),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text(
                      'COTS Trend',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: kTextNavy,
                      ),
                    )),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Weekly detection volume',
                  style: TextStyle(fontSize: 11, color: kMutedGray),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 88,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (spots.length - 1).toDouble().clamp(0, 6),
                      minY: 0,
                      maxY: analytics.maxTrendY,
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: kInfoBlue,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: kInfoBlue.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ticks every second so the dashboard clock stays accurate.
class _LiveDateTimeText extends StatefulWidget {
  const _LiveDateTimeText({required this.style});

  final TextStyle style;

  @override
  State<_LiveDateTimeText> createState() => _LiveDateTimeTextState();
}

class _LiveDateTimeTextState extends State<_LiveDateTimeText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      DateFormat('MMM d, yyyy h:mm:ss a').format(DateTime.now()),
      style: widget.style,
    );
  }
}
