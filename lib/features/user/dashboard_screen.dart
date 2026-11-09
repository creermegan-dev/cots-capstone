import 'dart:async';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../core/cots_colors.dart';
import '../../core/supabase_config.dart';
import '../../models/activity_type.dart';
import '../../models/intervention_assignment_model.dart';
import '../../models/scan_record_model.dart';
import '../../models/submission_group.dart';
import '../../models/monitoring_analytics.dart';
import '../../widgets/monitoring_record_map.dart';
import '../../widgets/cots_loading_skeleton.dart';
import '../../providers/auth_provider.dart';
import '../../services/intervention_assignment_repository.dart';
import '../../services/scan_record_repository.dart';
import 'cots_map_page.dart';
import 'notifications_screen.dart';
import 'profile_page.dart';
import 'records_page.dart';
import 'scan_detection_page.dart';
import 'user_analytics_overview_page.dart';
import 'user_bottom_nav.dart';
import 'user_dashboard_analytics.dart';
import 'widgets/diver_notification_bell.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.recordsStream});
  final Stream<List<ScanRecordModel>>? recordsStream;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Stream<List<ScanRecordModel>> _recordsStream;
  List<ScanRecordModel>? _lastRecords;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _recordsStream = widget.recordsStream ?? ScanRecordRepository.watchAll();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recordsStream != widget.recordsStream) {
      _retryTimer?.cancel();
      _lastRecords = null;
      _recordsStream = widget.recordsStream ?? ScanRecordRepository.watchAll();
    }
  }

  void _retry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (!mounted) return;
    setState(() {
      _recordsStream = widget.recordsStream ?? ScanRecordRepository.watchAll();
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Widget _loadNotice(Object error) {
    final offline = error is SocketException ||
        error is http.ClientException ||
        error is TimeoutException;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(offline ? 'Offline mode' : 'Dashboard temporarily unavailable',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_lastRecords == null
              ? 'Connect to load dashboard data. You can still open Detect and save submissions on this device for synchronization.'
              : 'Showing the last loaded dashboard data from this session. New submissions may not appear until synchronization finishes.'),
          const SizedBox(height: 8),
          const Text(
              'Pending submissions remain in Records. Reconnecting will retry loading automatically.'),
          TextButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry dashboard')),
        ]),
      ),
    );
  }

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
              stream: _recordsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData &&
                    _lastRecords == null) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(_horizontalPad, 8,
                        _horizontalPad, showSidebar ? 28 : 100),
                    child: const CotsLoadingSkeleton(
                        layout: CotsSkeletonLayout.dashboard),
                  );
                }
                if (snapshot.hasError) {
                  if (widget.recordsStream == null) {
                    _retryTimer ??= Timer(const Duration(seconds: 15), _retry);
                  }
                  if (_lastRecords == null) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
                      child: _loadNotice(snapshot.error!),
                    );
                  }
                } else if (snapshot.hasData) {
                  _lastRecords = snapshot.data;
                  _retryTimer?.cancel();
                  _retryTimer = null;
                }

                final records = snapshot.hasError
                    ? _lastRecords!
                    : snapshot.data ?? _lastRecords ?? [];
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
                      if (snapshot.hasError) _loadNotice(snapshot.error!),
                      _DashboardHeader(analytics: analytics, records: records),
                      const _AssignedTasksSection(),
                      const SizedBox(height: 16),
                      _MetricsGrid(records: records),
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
    // Scheduled removal tasks exist only in the Firebase version.
    if (user == null || SupabaseConfig.isConfigured) {
      return const SizedBox.shrink();
    }

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
                  'COTS Monitor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Diver Portal',
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
                  icon: Icons.event_repeat_outlined,
                  label: 'Monthly visits',
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
    final recent = [...SubmissionGroup.fromRecords(records)]..sort((a, b) {
        final ad = a.latestSubmittedAt ?? DateTime(1970);
        final bd = b.latestSubmittedAt ?? DateTime(1970);
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
              'No monitoring activities yet. Upload a photo to get started.',
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

  Widget _recentActivityRow(SubmissionGroup group) {
    final r = group.records.first;
    final when = group.latestSubmittedAt;
    final whenLabel = when == null
        ? '—'
        : DateFormat('MMM d, yyyy · h:mm a').format(when.toLocal());
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
                group.hasBatch
                    ? '${group.photoCount} photos · ${group.displayId}'
                    : isRemoval
                        ? 'Removal Evidence'
                        : 'Monitoring Capture',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: kTextNavy,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${r.zone.isEmpty ? 'Unassigned zone' : r.zone} · '
                '${group.hasBatch ? group.detectedCount : r.aiDetectedCount} COTS · ${group.statusLabel()}',
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

    final notifButton = DiverNotificationBell(
      uid: user?.uid,
      onPressed: () {
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const NotificationsScreen(),
          ),
        );
      },
    );

    // Minimal header: greeting + title on the left, bell on the right,
    // then one quiet line with the subtitle and the live date/time.
    final dateLine = Tooltip(
      message: recordUpdated == null
          ? 'Current device time'
          : 'Latest record ${DateFormat('MMM d, h:mm a').format(recordUpdated.toLocal())}',
      child: Row(
        key: const ValueKey('dashboard-clock'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded,
              size: 13, color: kMutedGray.withValues(alpha: 0.9)),
          const SizedBox(width: 4),
          const Flexible(
            child: _LiveDateTimeText(
              format: 'EEE, MMM d · h:mm a',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: kMutedGray,
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kSuccessGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Diver Dashboard',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: kTextNavy,
                      letterSpacing: -0.5,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            notifButton,
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Crown-of-Thorns Starfish Monitoring',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: kMutedGray,
          ),
        ),
        const SizedBox(height: 4),
        dateLine,
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.records});

  final List<ScanRecordModel> records;

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat.decimalPattern();
    final data = MonitoringAnalytics.fromRecords(records);
    final pending = data.pending;
    final confirmed = data.accepted;
    final removed = data.removalRecords.length;
    final captures = data.submissionCount;

    final card1 = _MetricCard(
      icon: Icons.photo_library_outlined,
      iconColor: kAccentPurple,
      iconBg: kAccentPurple.withValues(alpha: 0.12),
      title: 'Total submissions',
      value: nf.format(captures),
    );

    final card2 = _MetricCard(
      icon: Icons.hourglass_top_rounded,
      iconColor: const Color(0xFFE6A23C),
      iconBg: const Color(0xFFE6A23C).withValues(alpha: 0.12),
      title: 'Pending Validation',
      value: '$pending',
    );

    final card3 = _MetricCard(
      icon: Icons.verified_rounded,
      iconColor: kSuccessGreen,
      iconBg: kSuccessGreen.withValues(alpha: 0.12),
      title: 'COTS removed (confirmed)',
      value: '$confirmed',
    );

    final card4 = _MetricCard(
      icon: Icons.cleaning_services_outlined,
      iconColor: kInfoBlue,
      iconBg: kInfoBlue.withValues(alpha: 0.12),
      title: 'Removal Activities',
      value: '$removed',
    );

    return LayoutBuilder(
      builder: (context, c) {
        const gap = 12.0;
        final isFourColumns = c.maxWidth >= 840;

        if (isFourColumns) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: card1),
                const SizedBox(width: gap),
                Expanded(child: card2),
                const SizedBox(width: gap),
                Expanded(child: card3),
                const SizedBox(width: gap),
                Expanded(child: card4),
              ],
            ),
          );
        }

        return Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: gap),
                  Expanded(child: card2),
                ],
              ),
            ),
            const SizedBox(height: gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: card3),
                  const SizedBox(width: gap),
                  Expanded(child: card4),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String value;

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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: kTextNavy,
              letterSpacing: -0.4,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: kMutedGray,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
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
  const _LiveDateTimeText({
    required this.style,
    this.format = 'MMM d, yyyy\nh:mm a',
  });

  final TextStyle style;
  final String format;

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
      DateFormat(widget.format).format(DateTime.now()),
      style: widget.style,
    );
  }
}
