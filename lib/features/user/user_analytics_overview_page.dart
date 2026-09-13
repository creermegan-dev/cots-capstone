import 'package:cots_monitor/widgets/app_back_icon_button.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/cots_colors.dart';
import '../../models/scan_record_model.dart';
import '../../services/scan_record_repository.dart';
import 'user_dashboard_analytics.dart';

/// Full analytics overview (opened from dashboard "View more").
class UserAnalyticsOverviewPage extends StatefulWidget {
  const UserAnalyticsOverviewPage({super.key, this.initialAnalytics});

  final UserDashboardAnalytics? initialAnalytics;

  @override
  State<UserAnalyticsOverviewPage> createState() =>
      _UserAnalyticsOverviewPageState();
}

class _UserAnalyticsOverviewPageState extends State<UserAnalyticsOverviewPage> {
  String _trendGranularity = 'Daily';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: kTextNavy,
        leading: AppBackIconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          iconColor: kTextNavy,
        ),
        title: const Text(
          'Analytics Overview',
          style: TextStyle(
            color: kTextNavy,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<ScanRecordModel>>(
        stream: ScanRecordRepository.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData &&
              widget.initialAnalytics == null) {
            return const Center(
              child: CircularProgressIndicator(color: kPrimaryTeal),
            );
          }

          final analytics = snapshot.hasData && snapshot.data!.isNotEmpty
              ? UserDashboardAnalytics.fromRecords(snapshot.data!)
              : (widget.initialAnalytics ?? UserDashboardAnalytics.sample());

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 900;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (analytics.isSampleData)
                      _sampleBanner(),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _trendCard(analytics)),
                          const SizedBox(width: 14),
                          Expanded(child: _distributionCard(analytics)),
                        ],
                      )
                    else ...[
                      _trendCard(analytics),
                      const SizedBox(height: 14),
                      _distributionCard(analytics),
                    ],
                    const SizedBox(height: 14),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _severityCard(analytics)),
                          const SizedBox(width: 14),
                          Expanded(child: _confidenceCard(analytics)),
                        ],
                      )
                    else ...[
                      _severityCard(analytics),
                      const SizedBox(height: 14),
                      _confidenceCard(analytics),
                    ],
                    const SizedBox(height: 16),
                    _footerBanner(analytics),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _sampleBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kInfoBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kInfoBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: kInfoBlue.withValues(alpha: 0.9)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Showing sample analytics until GoPro submissions are recorded.',
              style: TextStyle(fontSize: 12, color: kTextNavy.withValues(alpha: 0.85)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _whiteCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderGray),
        boxShadow: kSoftCardShadow,
      ),
      child: child,
    );
  }

  Widget _trendCard(UserDashboardAnalytics a) {
    final spots = a.dailyTrendSpots;
    final labels = a.dailyTrendLabels;
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'COTS Detection Trend',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kTextNavy,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _trendGranularity,
                    borderRadius: BorderRadius.circular(10),
                    items: const [
                      DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                      DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                    ],
                    onChanged: (v) =>
                        setState(() => _trendGranularity = v ?? 'Daily'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (labels.length - 1).toDouble().clamp(0, 6),
                minY: 0,
                maxY: a.maxTrendY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: a.maxTrendY / 4,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Colors.black.withValues(alpha: 0.06),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: a.maxTrendY / 4,
                      getTitlesWidget: (v, m) => Text(
                        v.round().toString(),
                        style: const TextStyle(fontSize: 10, color: kMutedGray),
                      ),
                    ),
                    axisNameWidget: const Text(
                      'Detections',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kMutedGray,
                      ),
                    ),
                    axisNameSize: 18,
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (v, m) {
                        final i = v.round();
                        if (i < 0 || i >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[i],
                            style: const TextStyle(
                              fontSize: 9,
                              color: kMutedGray,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: kInfoBlue,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: kInfoBlue,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          kInfoBlue.withValues(alpha: 0.18),
                          kInfoBlue.withValues(alpha: 0.02),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              _DotLegend(color: kInfoBlue, label: 'COTS Detections'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _distributionCard(UserDashboardAnalytics a) {
    final total = a.zoneSlices.fold<int>(0, (s, z) => s + z.count);
    final sections = [
      for (final z in a.zoneSlices)
        if (z.count > 0)
          PieChartSectionData(
            value: z.count.toDouble(),
            color: Color(z.colorValue),
            title: '',
            radius: 52,
          ),
    ];

    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'COTS Distribution by Zone',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: kTextNavy,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 42,
                          sections: sections,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            NumberFormat.decimalPattern().format(total),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: kTextNavy,
                            ),
                          ),
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 11,
                              color: kMutedGray,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final z in a.zoneSlices) ...[
                        _zoneLegendRow(z, total),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoneLegendRow(ZoneSlice z, int total) {
    final pct = total == 0 ? 0.0 : 100 * z.count / total;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Color(z.colorValue),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            z.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          '${z.count} (${pct.toStringAsFixed(1)}%)',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: kTextNavy,
          ),
        ),
      ],
    );
  }

  Widget _severityCard(UserDashboardAnalytics a) {
    final maxY = a.maxSeverityY;
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Detections by Severity',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: kTextNavy,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Colors.black.withValues(alpha: 0.06),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: maxY / 4,
                      getTitlesWidget: (v, m) => Text(
                        v.round().toString(),
                        style: const TextStyle(fontSize: 10, color: kMutedGray),
                      ),
                    ),
                    axisNameWidget: const Text(
                      'Detections',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kMutedGray,
                      ),
                    ),
                    axisNameSize: 16,
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, m) {
                        const labels = ['High', 'Medium', 'Low'];
                        final i = v.round();
                        if (i < 0 || i > 2) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[i],
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _severityBar(0, a.severityHigh.toDouble(), maxY, kDangerRed),
                  _severityBar(
                    1,
                    a.severityMedium.toDouble(),
                    maxY,
                    kWarningOrange,
                  ),
                  _severityBar(2, a.severityLow.toDouble(), maxY, kSuccessGreen),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _severityBar(
    int x,
    double value,
    double maxY,
    Color color,
  ) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          width: 36,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          color: color,
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: maxY,
            color: const Color(0xFFF0F4F8),
          ),
        ),
      ],
    );
  }

  Widget _confidenceCard(UserDashboardAnalytics a) {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Confidence Level Summary',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: kTextNavy,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < a.confidenceRows.length; i++) ...[
            if (i > 0) const Divider(height: 20, color: kBorderGray),
            _confidenceRow(a.confidenceRows[i]),
          ],
        ],
      ),
    );
  }

  Widget _confidenceRow(ConfidenceRow row) {
    final color = Color(row.color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                row.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: kTextNavy,
                ),
              ),
            ),
            Text(
              '${row.detections}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 48,
              child: Text(
                '${(row.percent * 100).toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: kMutedGray,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: row.percent.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: const Color(0xFFF0F4F8),
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          row.description,
          style: const TextStyle(fontSize: 11, color: kMutedGray, height: 1.35),
        ),
      ],
    );
  }

  Widget _footerBanner(UserDashboardAnalytics a) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kInfoBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kInfoBlue.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: kInfoBlue.withValues(alpha: 0.9)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'All totals match the dashboard. Total COTS detected in selected period: '
              '${NumberFormat.decimalPattern().format(a.totalCots)}.',
              style: TextStyle(
                fontSize: 13,
                color: kTextNavy.withValues(alpha: 0.88),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotLegend extends StatelessWidget {
  const _DotLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: kMutedGray,
          ),
        ),
      ],
    );
  }
}
