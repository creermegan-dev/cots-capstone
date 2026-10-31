import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/cots_colors.dart';
import '../core/supabase_config.dart';
import '../models/cots_tally.dart';
import '../services/supabase_record_service.dart';
import '../models/cots_confidence_policy.dart';
import '../models/monitoring_analytics.dart';
import '../models/scan_record_model.dart';
import '../services/scan_record_repository.dart';
import 'cots_loading_skeleton.dart';

/// Loads confirmed COTS per removal method for the selected dates and zone.
typedef RemovalMethodLoader = Future<List<RemovalMethodCount>> Function(
    DateTime from, DateTime to, String? zone);

/// A live record subscription shared by Admin and Diver analytics.
class MonitoringAnalyticsPanel extends StatefulWidget {
  const MonitoringAnalyticsPanel(
      {super.key,
      this.recordsStream,
      this.now,
      this.trailingBuilder,
      this.removalMethodLoader});
  final Stream<List<ScanRecordModel>>? recordsStream;
  final DateTime? now;
  final Widget Function(BuildContext, List<ScanRecordModel>)? trailingBuilder;

  /// Stage 3: defaults to the database summary (Supabase only).
  final RemovalMethodLoader? removalMethodLoader;

  @override
  State<MonitoringAnalyticsPanel> createState() =>
      _MonitoringAnalyticsPanelState();
}

class _MonitoringAnalyticsPanelState extends State<MonitoringAnalyticsPanel> {
  late Stream<List<ScanRecordModel>> _stream;
  late DateTimeRange _range;
  String? _zone;
  String _granularity = 'Daily';
  @override
  void initState() {
    super.initState();
    _stream = widget.recordsStream ?? ScanRecordRepository.watchAll();
    final end = MonitoringAnalytics.day(widget.now ?? DateTime.now());
    _range =
        DateTimeRange(start: end.subtract(const Duration(days: 29)), end: end);
  }

  @override
  void didUpdateWidget(MonitoringAnalyticsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recordsStream != widget.recordsStream) {
      _stream = widget.recordsStream ?? ScanRecordRepository.watchAll();
    }
  }

  Future<void> _chooseDates() async {
    final now = widget.now ?? DateTime.now();
    final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year + 1),
        initialDateRange: _range);
    if (picked != null && mounted) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ScanRecordModel>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _card(
                'Analytics unavailable',
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text(
                      'Could not load monitoring records. Check your connection and try again.'),
                  TextButton.icon(
                      onPressed: () => setState(() {
                            _stream = widget.recordsStream ??
                                ScanRecordRepository.watchAll();
                          }),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry')),
                ]));
          }
          if (!snapshot.hasData) {
            return const CotsLoadingSkeleton(
                layout: CotsSkeletonLayout.analytics);
          }
          final records = snapshot.data!;
          final zones = MonitoringAnalytics.fromRecords(records).zones;
          final selectedZone = zones.contains(_zone) ? _zone : null;
          final data = MonitoringAnalytics.fromRecords(records,
              from: _range.start, to: _range.end, zone: selectedZone);
          final points = data.trend(_range.start, _range.end, _granularity);
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                          onPressed: _chooseDates,
                          icon: const Icon(Icons.date_range),
                          label: Text(
                              '${DateFormat('MMM d, yyyy').format(_range.start)} – ${DateFormat('MMM d, yyyy').format(_range.end)}')),
                      SizedBox(
                          width: 240,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(selectedZone),
                            initialValue: selectedZone ?? '',
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Monitoring zone',
                                border: OutlineInputBorder()),
                            items: [
                              const DropdownMenuItem(
                                  value: '', child: Text('All zones')),
                              for (final z in zones)
                                DropdownMenuItem(
                                    value: z,
                                    child: Text(z,
                                        overflow: TextOverflow.ellipsis))
                            ],
                            onChanged: (value) => setState(
                                () => _zone = value == '' ? null : value),
                          )),
                    ]),
                const SizedBox(height: 16),
                if (data.captures.isEmpty)
                  const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                          'No detection records for these dates and zone.',
                          key: ValueKey('analytics-empty'))),
                LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000
                      ? 3
                      : constraints.maxWidth >= 600
                          ? 2
                          : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  final metrics = <(String, String, String)>[
                    (
                      HonestReport.confirmedLabel,
                      '${data.accepted}',
                      'Every COTS found is removed. COTS the Expert rejected are not counted.'
                    ),
                    (
                      HonestReport.waitingLabel,
                      '${data.pending}',
                      '${data.pendingRecords} record(s), including other Divers\' records in assigned zones.'
                    ),
                    (
                      HonestReport.notAcceptedLabel,
                      '${data.rejected}',
                      'Rejected by the Expert or below 20% confidence.'
                    ),
                    (
                      'Monitoring captures',
                      '${data.captures.length}',
                      'Removal evidence and survey summaries excluded.'
                    ),
                    (
                      'Zones with records',
                      '${data.byZone.keys.where((z) => z != 'Unassigned').length}',
                      'Zones represented by the selected captures.'
                    ),
                    (
                      'Overall confidence',
                      data.averageConfidence == null
                          ? '—'
                          : '${data.averageConfidence!.round()}%',
                      'Average across individual COTS detections.'
                    ),
                  ];
                  return Wrap(spacing: 12, runSpacing: 12, children: [
                    for (final m in metrics)
                      SizedBox(
                          width: width,
                          child: _card(
                              m.$1,
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.$2,
                                        key: ValueKey('metric-${m.$1}'),
                                        style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800,
                                            color: kPrimaryTeal)),
                                    Text(m.$3,
                                        style: const TextStyle(
                                            color: kMutedGray, fontSize: 12)),
                                  ]))),
                  ]);
                }),
                const SizedBox(height: 16),
                _card(
                    'Confirmed COTS trend',
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                              alignment: Alignment.centerRight,
                              child: DropdownButton<String>(
                                value: _granularity,
                                items: [
                                  for (final v in [
                                    'Daily',
                                    'Weekly',
                                    'Monthly'
                                  ])
                                    DropdownMenuItem(value: v, child: Text(v))
                                ],
                                onChanged: (v) =>
                                    setState(() => _granularity = v ?? 'Daily'),
                              )),
                          if (points.isNotEmpty) _trendChart(points),
                        ])),
                const SizedBox(height: 16),
                _card('Confirmed COTS by zone', _zoneChart(data)),
                const SizedBox(height: 16),
                _card(
                    'Verification status',
                    Column(children: [
                      _countRow('Confirmed', data.accepted, data.totalCots,
                          kSuccessGreen),
                      _countRow(HonestReport.waitingLabel, data.pending,
                          data.totalCots, kWarningOrange),
                      _countRow(HonestReport.notAcceptedLabel, data.rejected,
                          data.totalCots, kDangerRed),
                    ])),
                const SizedBox(height: 16),
                _card(
                    'AI confidence levels',
                    Column(children: [
                      _countRow(
                          '80–100%',
                          data.confidenceBands[
                              CotsVerificationBand.aiAutoApproved.index],
                          data.totalCots,
                          kSuccessGreen),
                      _countRow(
                          '20–79%',
                          data.confidenceBands[
                              CotsVerificationBand.adminReview.index],
                          data.totalCots,
                          kWarningOrange),
                      _countRow(
                          'Below 20%',
                          data.confidenceBands[
                              CotsVerificationBand.retakeRequired.index],
                          data.totalCots,
                          kDangerRed),
                    ])),
                const SizedBox(height: 16),
                _card(
                    'Removal methods',
                    _RemovalMethods(
                      from: _range.start,
                      to: _range.end,
                      zone: selectedZone,
                      loader: widget.removalMethodLoader ??
                          (SupabaseConfig.isConfigured
                              ? (from, to, zone) =>
                                  SupabaseRecordService.removalMethodSummary(
                                      from: from, to: to, zone: zone)
                              : null),
                    )),
                if (widget.trailingBuilder != null)
                  widget.trailingBuilder!(context, data.captures),
              ]);
        },
      );

  Widget _trendChart(List<MonitoringTrendPoint> points) {
    final maxY =
        math.max(1, points.map((p) => p.count).reduce(math.max)).toDouble();
    final step = math.max(1, (points.length / 5).ceil()).toDouble();
    return SizedBox(
        height: 240,
        child: LineChart(LineChartData(
          minX: 0,
          maxX: math.max(1, points.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: math.max(1, (maxY / 4).ceil()).toDouble(),
                    getTitlesWidget: (v, _) => Text('${v.round()}',
                        style: const TextStyle(fontSize: 10)))),
            bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: step,
                    getTitlesWidget: (v, _) {
                      final i = v.round();
                      return i < 0 || i >= points.length
                          ? const SizedBox.shrink()
                          : Text(DateFormat('MMM d').format(points[i].date),
                              style: const TextStyle(fontSize: 10));
                    })),
          ),
          lineBarsData: [
            LineChartBarData(
                spots: [
                  for (var i = 0; i < points.length; i++)
                    FlSpot(i.toDouble(), points[i].count.toDouble())
                ],
                color: kInfoBlue,
                barWidth: 3,
                isCurved: false,
                dotData: const FlDotData(show: false))
          ],
        )));
  }

  Widget _zoneChart(MonitoringAnalytics data) {
    final entries = data.byZone.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return const Text('No confirmed COTS to display.');
    const colors = [
      kPrimaryTeal,
      kInfoBlue,
      kAccentPurple,
      kWarningOrange,
      kSuccessGreen
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
          height: 220,
          child: PieChart(PieChartData(centerSpaceRadius: 45, sections: [
            for (var i = 0; i < entries.length; i++)
              PieChartSectionData(
                  value: entries[i].value.toDouble(),
                  color: colors[i % colors.length],
                  radius: 45,
                  title: '')
          ]))),
      for (var i = 0; i < entries.length; i++)
        _countRow(entries[i].key, entries[i].value, data.accepted,
            colors[i % colors.length]),
    ]);
  }

  Widget _countRow(String label, int count, int total, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
              '$label: $count (${total == 0 ? '0' : (count * 100 / total).toStringAsFixed(1)}%)'),
          const SizedBox(height: 4),
          LinearProgressIndicator(
              value: total == 0 ? 0 : count / total,
              color: color,
              backgroundColor: color.withValues(alpha: .12)),
        ]),
      );

  Widget _card(String title, Widget child) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: kSoftCardShadow),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: kTextNavy, fontSize: 16)),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

/// Stage 3: confirmed COTS per removal method, as a pie with the numbers
/// listed under it (COTS, share and number of removals).
class _RemovalMethods extends StatefulWidget {
  const _RemovalMethods({
    required this.from,
    required this.to,
    required this.zone,
    required this.loader,
  });

  final DateTime from;
  final DateTime to;
  final String? zone;
  final RemovalMethodLoader? loader;

  @override
  State<_RemovalMethods> createState() => _RemovalMethodsState();
}

class _RemovalMethodsState extends State<_RemovalMethods> {
  static const _colors = {
    RemovalMethodCount.manualLabel: kInfoBlue,
    RemovalMethodCount.vinegarLabel: kWarningOrange,
    RemovalMethodCount.oxBileLabel: kSuccessGreen,
    RemovalMethodCount.otherLabel: kMutedGray,
  };

  Future<List<RemovalMethodCount>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_RemovalMethods oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.from != widget.from ||
        oldWidget.to != widget.to ||
        oldWidget.zone != widget.zone) {
      _load();
    }
  }

  void _load() {
    final loader = widget.loader;
    _future = loader == null
        ? null
        : loader(widget.from, widget.to, widget.zone)
            .then(RemovalMethodCount.group);
  }

  @override
  Widget build(BuildContext context) {
    const note = Text(
        'Confirmed COTS only: records waiting for the Expert count after '
        'approval. Zones are never marked cleared; density is calculated for '
        'each monthly visit.',
        style: TextStyle(color: kMutedGray, fontSize: 12));
    final future = _future;
    if (future == null) {
      return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Removal method counts are available with the Supabase '
                'backend.'),
            SizedBox(height: 8),
            note,
          ]);
    }
    return FutureBuilder<List<RemovalMethodCount>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Could not load removal methods.'),
                TextButton.icon(
                    onPressed: () => setState(_load),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry')),
              ]);
        }
        if (!snapshot.hasData) {
          return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()));
        }
        final rows = snapshot.data!;
        final total = rows.fold<int>(0, (sum, row) => sum + row.cots);
        if (total == 0) {
          return const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No confirmed removals for these dates and zone.',
                    key: ValueKey('removal-methods-empty')),
                SizedBox(height: 8),
                note,
              ]);
        }
        int percent(int cots) => (cots * 100 / total).round();
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                  height: 200,
                  child: PieChart(PieChartData(
                      centerSpaceRadius: 0,
                      sectionsSpace: 2,
                      sections: [
                        for (final row in rows)
                          PieChartSectionData(
                              value: row.cots.toDouble(),
                              color: _colors[row.method] ?? kMutedGray,
                              radius: 90,
                              title: percent(row.cots) >= 8
                                  ? '${percent(row.cots)}%'
                                  : '',
                              titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                      ]))),
              const SizedBox(height: 12),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            color: _colors[row.method] ?? kMutedGray,
                            borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${row.method}: ${row.cots} COTS · '
                        '${percent(row.cots)}% · ${row.removals} '
                        'removal${row.removals == 1 ? '' : 's'}',
                        key: ValueKey('removal-method-${row.method}'),
                      ),
                    ),
                  ]),
                ),
              const SizedBox(height: 8),
              note,
            ]);
      },
    );
  }
}
