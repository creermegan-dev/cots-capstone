import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/cots_colors.dart';
import '../models/cots_confidence_policy.dart';
import '../models/monitoring_analytics.dart';
import '../models/scan_record_model.dart';
import '../services/scan_record_repository.dart';
import 'cots_loading_skeleton.dart';

/// A live record subscription shared by Admin and Diver analytics.
class MonitoringAnalyticsPanel extends StatefulWidget {
  const MonitoringAnalyticsPanel(
      {super.key, this.recordsStream, this.now, this.trailingBuilder});
  final Stream<List<ScanRecordModel>>? recordsStream;
  final DateTime? now;
  final Widget Function(BuildContext, List<ScanRecordModel>)? trailingBuilder;

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
                      'Total COTS detections',
                      '${data.totalCots}',
                      'Image observations; repeated sightings may occur.'
                    ),
                    (
                      'Accepted COTS detections',
                      '${data.accepted}',
                      'AI auto-acceptance or Expert confirmation.'
                    ),
                    (
                      'COTS awaiting Expert review',
                      '${data.pending}',
                      '${data.pendingRecords} monitoring record(s).'
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
                    'COTS detection trend',
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
                _card('COTS detections by zone', _zoneChart(data)),
                const SizedBox(height: 16),
                _card(
                    'Verification status',
                    Column(children: [
                      _countRow('Accepted', data.accepted, data.totalCots,
                          kSuccessGreen),
                      _countRow('Awaiting Expert review', data.pending,
                          data.totalCots, kWarningOrange),
                      _countRow('Rejected / retake required', data.rejected,
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
                    'Removal activity',
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${data.removalRecords.length} recorded removal activities'),
                          Text(
                              'Reported eliminated quantity: ${data.removalRecords.isNotEmpty && data.unreportedRemovals == data.removalRecords.length ? 'Not reported' : data.reportedEliminated}'),
                          if (data.unreportedRemovals > 0)
                            Text(
                                '${data.unreportedRemovals} activity record(s) have no reported eliminated quantity.'),
                          const SizedBox(height: 8),
                          const Text(
                              'Area clearance and COTS density are unavailable without a verified area survey.',
                              style: TextStyle(color: kMutedGray)),
                        ])),
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
    if (entries.isEmpty) return const Text('No COTS detections to display.');
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
        _countRow(entries[i].key, entries[i].value, data.totalCots,
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
