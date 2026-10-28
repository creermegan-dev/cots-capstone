import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/monitoring_analytics.dart';
import '../../../models/scan_record_model.dart';
import '../../../services/scan_record_repository.dart';
import '../../../widgets/cots_loading_skeleton.dart';
import '../layout/admin_breakpoints.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dashboard_header.dart';

class AdminZonesScreen extends StatefulWidget {
  const AdminZonesScreen({super.key});

  @override
  State<AdminZonesScreen> createState() => _AdminZonesScreenState();
}

class _AdminZonesScreenState extends State<AdminZonesScreen> {
  final _search = TextEditingController();
  late Stream<List<ScanRecordModel>> _recordsStream;

  @override
  void initState() {
    super.initState();
    _recordsStream = ScanRecordRepository.watchAll();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() => _recordsStream = ScanRecordRepository.watchAll());
  }

  @override
  Widget build(BuildContext context) {
    final padding =
        AdminBreakpoints.pagePadding(MediaQuery.sizeOf(context).width);
    return StreamBuilder<List<ScanRecordModel>>(
      stream: _recordsStream,
      builder: (context, snapshot) {
        final rows =
            snapshot.hasData ? _summaries(snapshot.data!) : <_ZoneSummary>[];
        final query = _search.text.trim().toLowerCase();
        final visible = query.isEmpty
            ? rows
            : rows
                .where((row) => row.zone.toLowerCase().contains(query))
                .toList();
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(padding.left, 22, padding.right, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminDashboardHeader(
                title: 'Monitoring Areas',
                subtitle: 'Area summaries calculated from saved field records.',
                onRefreshTap: _refresh,
              ),
              const SizedBox(height: 18),
              if (snapshot.hasError)
                _stateCard('Could not load monitoring areas.', retry: _refresh)
              else if (!snapshot.hasData)
                const CotsLoadingSkeleton(
                  layout: CotsSkeletonLayout.table,
                  label: 'Loading monitoring areas',
                )
              else ...[
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search monitoring areas…',
                    prefixIcon: Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                if (visible.isEmpty)
                  _stateCard('No saved records match this area search.')
                else
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _ZoneSummaryCard(summary: visible[i]),
                  ],
              ],
            ],
          ),
        );
      },
    );
  }

  List<_ZoneSummary> _summaries(List<ScanRecordModel> records) {
    final groups = <String, List<ScanRecordModel>>{};
    for (final record in records.where(MonitoringAnalytics.isCapture)) {
      groups
          .putIfAbsent(MonitoringAnalytics.zoneName(record), () => [])
          .add(record);
    }
    final result = groups.entries.map((entry) {
      final sorted = [...entry.value]..sort((a, b) =>
          (b.submittedAt ?? b.dateTaken ?? DateTime(1970))
              .compareTo(a.submittedAt ?? a.dateTaken ?? DateTime(1970)));
      final analytics = MonitoringAnalytics.fromRecords(sorted);
      return _ZoneSummary(
        zone: entry.key,
        reports: sorted.length,
        detections: analytics.totalCots,
        pending: analytics.pendingRecords,
        lastActivity: sorted.first.submittedAt ?? sorted.first.dateTaken,
      );
    }).toList()
      ..sort((a, b) => b.detections.compareTo(a.detections));
    return result;
  }

  Widget _stateCard(String message, {VoidCallback? retry}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          if (retry != null)
            TextButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

class _ZoneSummary {
  const _ZoneSummary({
    required this.zone,
    required this.reports,
    required this.detections,
    required this.pending,
    required this.lastActivity,
  });

  final String zone;
  final int reports;
  final int detections;
  final int pending;
  final DateTime? lastActivity;
}

class _ZoneSummaryCard extends StatelessWidget {
  const _ZoneSummaryCard({required this.summary});
  final _ZoneSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 240,
            child: Text(summary.zone,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AdminColors.headerTitle)),
          ),
          _metric('Reports', '${summary.reports}'),
          _metric('AI detections', '${summary.detections}'),
          _metric('Pending review', '${summary.pending}'),
          _metric(
            'Last activity',
            summary.lastActivity == null
                ? 'Not available'
                : DateFormat('MMM d, yyyy · h:mm a')
                    .format(summary.lastActivity!.toLocal()),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => SizedBox(
        width: 145,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 11.5, color: AdminColors.muted)),
            const SizedBox(height: 3),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AdminColors.headerTitle)),
          ],
        ),
      );
}
