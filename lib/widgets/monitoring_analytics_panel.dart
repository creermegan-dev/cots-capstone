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
import '../models/zone_directory_summary.dart';
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
      this.removalMethodLoader,
      this.useSiteTerminology = false,
      this.showHeaderFilters = true,
      this.dashboardLayout = false});
  final Stream<List<ScanRecordModel>>? recordsStream;
  final DateTime? now;
  final Widget Function(BuildContext, List<ScanRecordModel>)? trailingBuilder;

  /// Stage 3: defaults to the database summary (Supabase only).
  final RemovalMethodLoader? removalMethodLoader;

  /// When false, the date picker and zone dropdown at the top of the panel are hidden.
  final bool showHeaderFilters;
  final bool useSiteTerminology;
  final bool dashboardLayout;

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
                if (widget.showHeaderFilters) ...[
                  Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                            onPressed: _chooseDates,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E293B),
                              backgroundColor: Colors.white,
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.calendar_today_outlined,
                                size: 16, color: Color(0xFF008D94)),
                            label: Text(
                                '${DateFormat('MMM d, yyyy').format(_range.start)} – ${DateFormat('MMM d, yyyy').format(_range.end)}',
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B)))),
                        SizedBox(
                            width: 220,
                            height: widget.dashboardLayout ? null : 44,
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(selectedZone),
                              initialValue: selectedZone ?? '',
                              isExpanded: true,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                              icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: Color(0xFF64748B)),
                              decoration: InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                prefixIcon: const Icon(Icons.place_outlined,
                                    size: 18, color: Color(0xFF008D94)),
                                prefixIconConstraints: const BoxConstraints(
                                    minWidth: 36, minHeight: 44),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF008D94), width: 1.5),
                                ),
                              ),
                              items: [
                                DropdownMenuItem(
                                    value: '',
                                    child: Text(widget.useSiteTerminology
                                        ? 'All sites'
                                        : 'All zones')),
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
                ],
                if (data.captures.isEmpty)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        key: const ValueKey('analytics-empty'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 17, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.useSiteTerminology
                                    ? 'No detection records for these dates and site.'
                                    : 'No detection records for these dates and zone.',
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000
                      ? 3
                      : constraints.maxWidth >= 600
                          ? 2
                          : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  final metrics = <(String, String, String, IconData, Color)>[
                    (
                      HonestReport.confirmedLabel,
                      '${data.accepted}',
                      'Every COTS found is removed. COTS the Expert rejected are not counted.',
                      Icons.verified_outlined,
                      widget.dashboardLayout
                          ? kSuccessGreen
                          : const Color(0xFF008D94),
                    ),
                    (
                      HonestReport.waitingLabel,
                      '${data.pending}',
                      '${data.pendingSubmissionCount} submission(s), including other Divers\' records in assigned ${widget.useSiteTerminology ? 'sites' : 'zones'}.',
                      Icons.schedule_rounded,
                      const Color(0xFFD97706),
                    ),
                    (
                      HonestReport.notAcceptedLabel,
                      '${data.rejected}',
                      'Rejected by the Expert or below 20% confidence.',
                      Icons.cancel_outlined,
                      const Color(0xFFDC2626),
                    ),
                    (
                      'Monitoring submissions',
                      '${data.submissionCount}',
                      'Removal evidence and survey summaries excluded.',
                      Icons.camera_alt_outlined,
                      const Color(0xFF2563EB),
                    ),
                    (
                      widget.useSiteTerminology
                          ? 'Sites with records'
                          : 'Zones with records',
                      widget.useSiteTerminology
                          ? '${SiteDirectorySummary.fromRecords(data.captures).where((row) => row.reports > 0).length}'
                          : '${data.byZone.keys.where((z) => z != 'Unassigned').length}',
                      widget.useSiteTerminology
                          ? 'Sites represented by the selected captures.'
                          : 'Zones represented by the selected captures.',
                      Icons.explore_outlined,
                      const Color(0xFF7C3AED),
                    ),
                    (
                      'Overall confidence',
                      data.averageConfidence == null
                          ? '—'
                          : '${data.averageConfidence!.round()}%',
                      'Average across individual COTS detections.',
                      Icons.insights_rounded,
                      const Color(0xFF0D9488),
                    ),
                  ];
                  final cards = <Widget>[
                    for (final m in metrics)
                      SizedBox(
                          width: width,
                          child: _MetricStatCard(
                            title: m.$1,
                            value: m.$2,
                            description: m.$3,
                            icon: m.$4,
                            accentColor: m.$5,
                            compact: widget.dashboardLayout,
                          )),
                  ];
                  if (widget.dashboardLayout) {
                    return Column(children: [
                      for (var i = 0; i < cards.length; i += columns) ...[
                        if (i > 0) const SizedBox(height: 12),
                        IntrinsicHeight(
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              for (var j = i;
                                  j < math.min(i + columns, cards.length);
                                  j++) ...[
                                if (j > i) const SizedBox(width: 12),
                                Expanded(child: cards[j]),
                              ],
                            ])),
                      ],
                    ]);
                  }
                  return Wrap(spacing: 12, runSpacing: 12, children: cards);
                }),
                const SizedBox(height: 16),
                _chartGrid([
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
                                  onChanged: (v) => setState(
                                      () => _granularity = v ?? 'Daily'),
                                )),
                            if (points.isNotEmpty) _trendChart(points),
                          ])),
                  _card(
                      widget.useSiteTerminology
                          ? 'Confirmed COTS by site'
                          : 'Confirmed COTS by zone',
                      _zoneChart(data)),
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
                ]),
                const SizedBox(height: 16),
                _card(
                    'Removal methods',
                    _RemovalMethods(
                      useSiteTerminology: widget.useSiteTerminology,
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

  Widget _chartGrid(List<Widget> cards) =>
      LayoutBuilder(builder: (context, constraints) {
        if (!widget.dashboardLayout || constraints.maxWidth < 900) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  cards[i],
                ],
              ]);
        }
        return Column(children: [
          for (var i = 0; i < cards.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: cards[i]),
              const SizedBox(width: 16),
              Expanded(
                  child: i + 1 < cards.length
                      ? cards[i + 1]
                      : const SizedBox.shrink()),
            ]),
          ],
        ]);
      });

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
    final chart = SizedBox(
        height: 220,
        child: Stack(alignment: Alignment.center, children: [
          PieChart(PieChartData(
              centerSpaceRadius: widget.dashboardLayout ? 48 : 45,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                      value: entries[i].value.toDouble(),
                      color: colors[i % colors.length],
                      radius: widget.dashboardLayout ? 40 : 45,
                      title: ''),
              ])),
          if (widget.dashboardLayout)
            Text('${data.accepted}\nconfirmed',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kTextNavy)),
        ]));
    final legend =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < entries.length; i++)
        _countRow(entries[i].key, entries[i].value, data.accepted,
            colors[i % colors.length]),
    ]);
    return LayoutBuilder(builder: (context, constraints) {
      if (widget.dashboardLayout && constraints.maxWidth >= 400) {
        return Row(children: [
          SizedBox(width: 180, child: chart),
          const SizedBox(width: 16),
          Expanded(child: legend)
        ]);
      }
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [chart, legend]);
    });
  }

  Widget _countRow(String label, int count, int total, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.dashboardLayout)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Text(label,
                      style: const TextStyle(fontSize: 12, color: kTextNavy))),
              const SizedBox(width: 8),
              Text('$count',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kTextNavy)),
              const SizedBox(width: 6),
              Text(
                  '${total == 0 ? '0' : (count * 100 / total).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 11, color: kMutedGray)),
            ])
          else
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
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ]),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: kTextNavy, fontSize: 16)),
          const SizedBox(height: 14),
          child,
        ]),
      );
}

class _MetricStatCard extends StatelessWidget {
  const _MetricStatCard({
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
    required this.accentColor,
    this.compact = false,
  });

  final String title;
  final String value;
  final String description;
  final IconData icon;
  final Color accentColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                    fontSize: compact ? 12.5 : 13.5,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: compact ? 28 : 32,
                height: compact ? 28 : 32,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accentColor, size: 17),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 10),
          Text(
            value,
            key: ValueKey('metric-$title'),
            style: TextStyle(
              fontSize: compact ? 26 : 28,
              fontWeight: FontWeight.w800,
              color: accentColor,
              height: 1.0,
              letterSpacing: -0.5,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
    if (!compact) return card;
    return Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('analytics-info-$title'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                    title: Text(title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    scrollable: true,
                    content: Text(description,
                        style: const TextStyle(fontSize: 13, height: 1.4)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Close'))
                    ],
                  )),
          child: card,
        ));
  }
}

/// Stage 3: confirmed COTS per removal method, as a pie with the numbers
/// listed under it (COTS, share and number of removals).
class _RemovalMethods extends StatefulWidget {
  const _RemovalMethods({
    required this.from,
    required this.to,
    required this.zone,
    required this.loader,
    this.useSiteTerminology = false,
  });

  final DateTime from;
  final DateTime to;
  final String? zone;
  final RemovalMethodLoader? loader;
  final bool useSiteTerminology;

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
    final note = Text(
        'Confirmed COTS only: records waiting for the Expert count after '
        'approval. ${widget.useSiteTerminology ? 'Sites' : 'Zones'} are never marked cleared; density is calculated for '
        'each monthly visit.',
        style: const TextStyle(color: kMutedGray, fontSize: 12));
    final future = _future;
    if (future == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Removal method counts are available with the Supabase '
            'backend.'),
        const SizedBox(height: 8),
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
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    widget.useSiteTerminology
                        ? 'No confirmed removals for these dates and site.'
                        : 'No confirmed removals for these dates and zone.',
                    key: const ValueKey('removal-methods-empty')),
                const SizedBox(height: 8),
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
