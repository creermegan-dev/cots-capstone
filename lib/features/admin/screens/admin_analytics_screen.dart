import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';
import '../widgets/admin_data_table.dart';

int _analyticsSafeAxisIndex(double v, int maxIndex) {
  if (!v.isFinite || maxIndex < 0) return 0;
  return v.round().clamp(0, maxIndex);
}

String _analyticsSafeIntAxisLabel(double v) {
  if (!v.isFinite) return '';
  return '${v.round()}';
}

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  bool _showTopBanner = true;
  String _zone = 'All Zones';
  String _trendGranularity = 'Daily';
  int _refreshGeneration = 0;

  void _onAnalyticsRefresh() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Analytics refreshed.'),
      ),
    );
    setState(() => _refreshGeneration++);
  }

  static const List<AdminDataTableColumn> _confidenceSummaryColumns = [
    AdminDataTableColumn('Confidence Level', 208),
    AdminDataTableColumn('Detections', 96, headerAlign: TextAlign.right),
    AdminDataTableColumn('Percentage', 200, headerAlign: TextAlign.right),
    AdminDataTableColumn('Description', 384),
  ];

  static const _headerBorder = Color(0xFFE2E8F0);

  static const _zones = ['All Zones', 'Zone A', 'Zone B', 'Zone C', 'Zone D'];

  static const _trendLabels = ['May 12', 'May 13', 'May 14', 'May 15', 'May 16', 'May 17', 'May 18'];
  static const _trendSpots = [
    FlSpot(0, 35),
    FlSpot(1, 60),
    FlSpot(2, 48),
    FlSpot(3, 80),
    FlSpot(4, 50),
    FlSpot(5, 32),
    FlSpot(6, 55),
  ];

  static const _donutTotal = 248;
  static final _donutSections = [
    PieChartSectionData(value: 78, color: AdminColors.statBlue, title: '', radius: 52),
    PieChartSectionData(value: 62, color: AdminColors.statGreen, title: '', radius: 52),
    PieChartSectionData(value: 52, color: AdminColors.statYellow, title: '', radius: 52),
    PieChartSectionData(value: 36, color: AdminColors.statPurple, title: '', radius: 52),
    PieChartSectionData(value: 20, color: const Color(0xFF90A4AE), title: '', radius: 52),
  ];

  static const _donutLegend = <(String, int, String)>[
    ('Zone A — North Reef', 78, '31.5%'),
    ('Zone B — South Reef', 62, '25.0%'),
    ('Zone C — East Reef', 52, '21.0%'),
    ('Zone D — West Reef', 36, '14.5%'),
    ('Other Zones', 20, '8.0%'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: ValueKey<int>(_refreshGeneration),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          if (_showTopBanner) ...[
            const SizedBox(height: 16),
            _infoBanner(
              message: 'Analytics is based on alert data from your system for the selected period.',
              onClose: () => setState(() => _showTopBanner = false),
            ),
          ],
          const SizedBox(height: 18),
          _topCards(),
          const SizedBox(height: 18),
          _citizenScienceCards(),
          const SizedBox(height: 18),
          _sizeDistributionCard(),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth < 1000) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _trendCard(),
                    const SizedBox(height: 16),
                    _distributionCard(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _trendCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _distributionCard()),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth < 1000) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _severityBarCard(),
                    const SizedBox(height: 16),
                    _confidenceCard(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _severityBarCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _confidenceCard()),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _infoBanner(
            message: 'All totals match the dashboard. Total COTS detected in selected period: $_donutTotal',
            onClose: null,
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 720;
        final dateBtn = OutlinedButton.icon(
          onPressed: () {},
          icon: AdminDateTimeTokens.dateChipIcon(),
          label: const Text(AdminDateTimeTokens.demoDateRangeLabel, style: AdminDateTimeTokens.dateRangeChipTextStyle),
          style: AdminDateTimeTokens.dateRangeOutlinedButtonStyle(),
        );
        final refreshBtn = OutlinedButton.icon(
          onPressed: _onAnalyticsRefresh,
          icon: AdminDateTimeTokens.refreshIcon,
          label: const Text('Refresh', style: AdminDateTimeTokens.refreshChipTextStyle),
          style: AdminDateTimeTokens.refreshOutlinedButtonStyle(),
        );
        const titleStyle = TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AdminColors.headerTitle,
          letterSpacing: -0.4,
          height: 1.15,
        );
        final subtitleStyle = TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.35,
          color: AdminColors.muted.withValues(alpha: 0.95),
        );
        final zoneFilter = Align(
          alignment: Alignment.centerLeft,
          child: _analyticsZoneFilter(narrow ? c.maxWidth : 220),
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Analytics', style: titleStyle),
              const SizedBox(height: 5),
              Text('COTS trends and insights based on detected alerts.', style: subtitleStyle),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [dateBtn, refreshBtn],
              ),
              const SizedBox(height: 12),
              zoneFilter,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Analytics', style: titleStyle),
                      const SizedBox(height: 5),
                      Text('COTS trends and insights based on detected alerts.', style: subtitleStyle),
                    ],
                  ),
                ),
                dateBtn,
                const SizedBox(width: 10),
                refreshBtn,
              ],
            ),
            const SizedBox(height: 14),
            zoneFilter,
          ],
        );
      },
    );
  }

  /// Zone picker below the title row; fixed height matches date/refresh so nothing clips.
  Widget _analyticsZoneFilter(double maxDropdownWidth) {
    const labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Color(0xFF334155),
    );
    final w = maxDropdownWidth.isFinite ? maxDropdownWidth.clamp(200.0, 280.0) : 220.0;
    return SizedBox(
      width: w,
      height: 44,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _headerBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _zone,
                isExpanded: true,
                isDense: true,
                borderRadius: BorderRadius.circular(10),
                dropdownColor: Colors.white,
                icon: Icon(Icons.filter_list_rounded, size: 20, color: AdminColors.muted.withValues(alpha: 0.85)),
                style: labelStyle,
                selectedItemBuilder: (context) {
                  return _zones
                      .map(
                        (e) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            e,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: labelStyle,
                          ),
                        ),
                      )
                      .toList();
                },
                items: _zones
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e,
                        child: Text(e, style: labelStyle),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _zone = v ?? 'All Zones'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoBanner({required String message, VoidCallback? onClose}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.statBlue.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AdminColors.statBlue.withValues(alpha: 0.9), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AdminColors.headerTitle.withValues(alpha: 0.88),
                height: 1.35,
              ),
            ),
          ),
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, size: 20),
              style: IconButton.styleFrom(foregroundColor: AdminColors.muted),
            ),
        ],
      ),
    );
  }

  Widget _citizenScienceCards() {
    return LayoutBuilder(
      builder: (context, c) {
        final cards = [
          _InsightCard(
            iconBg: AdminColors.statRed.withValues(alpha: 0.12),
            icon: Icons.delete_sweep_outlined,
            iconColor: AdminColors.statRed,
            title: 'Total Removed COTS',
            value: '142',
            subtext: 'Citizen removal activities',
            subtextColor: AdminColors.headerTitle.withValues(alpha: 0.75),
            footer: 'Removal monitoring this period.',
            footerIcon: true,
          ),
          _InsightCard(
            iconBg: AdminColors.statYellow.withValues(alpha: 0.12),
            icon: Icons.straighten_rounded,
            iconColor: AdminColors.statYellow,
            title: 'Average Size Structure',
            value: '35 cm',
            subtext: 'Mean when reference visible',
            subtextColor: AdminColors.headerTitle.withValues(alpha: 0.75),
            footer: 'Based on GoPro removal records.',
            footerIcon: true,
          ),
          _InsightCard(
            iconBg: AdminColors.statGreen.withValues(alpha: 0.12),
            icon: Icons.groups_outlined,
            iconColor: AdminColors.statGreen,
            title: 'Citizen Contributions',
            value: '68',
            subtext: 'GoPro image submissions',
            subtextColor: AdminColors.headerTitle.withValues(alpha: 0.75),
            footer: 'Divers and citizen scientists.',
            footerIcon: true,
          ),
        ];
        if (c.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                cards[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _sizeDistributionCard() {
    const buckets = ['0–20 cm', '21–35 cm', '36–50 cm', '50+ cm'];
    const values = [18.0, 42.0, 28.0, 12.0];
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'COTS Size Distribution',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AdminColors.headerTitle,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Removal records with measurement reference (demo).',
            style: TextStyle(
              fontSize: 12,
              color: AdminColors.muted.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 50,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          buckets[_analyticsSafeAxisIndex(v, buckets.length - 1)],
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < values.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: values[i],
                          color: AdminColors.statBlue,
                          width: 28,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topCards() {
    return LayoutBuilder(
      builder: (context, c) {
        final cards = [
          _InsightCard(
            iconBg: AdminColors.statBlue.withValues(alpha: 0.12),
            icon: Icons.trending_up_rounded,
            iconColor: AdminColors.statBlue,
            title: 'Trend Direction',
            value: 'Increasing',
            subtext: '↑ 18% vs May 5 – May 11',
            subtextColor: AdminColors.statGreen,
            footer: 'COTS detections are on the rise this week.',
            footerIcon: true,
          ),
          _InsightCard(
            iconBg: AdminColors.statGreen.withValues(alpha: 0.12),
            icon: Icons.location_on_outlined,
            iconColor: AdminColors.statGreen,
            title: 'Most Affected Zone',
            value: 'Zone A — North Reef',
            valueColor: AdminColors.statGreen,
            subtext: '78 detections (31.5% of total)',
            subtextColor: AdminColors.headerTitle.withValues(alpha: 0.75),
            footer: 'Highest COTS activity this period.',
            footerIcon: true,
          ),
          _InsightCard(
            iconBg: AdminColors.statPurple.withValues(alpha: 0.12),
            icon: Icons.verified_user_outlined,
            iconColor: AdminColors.statPurple,
            title: 'Average Confidence',
            value: '82%',
            valueColor: AdminColors.statPurple,
            subtext: '',
            subtextColor: AdminColors.muted,
            footer: 'Based on all detections this period.',
            footerIcon: false,
          ),
        ];
        if (c.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                cards[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _trendCard() {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'COTS Detection Trend',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AdminColors.headerTitle),
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
                    dropdownColor: Colors.white,
                    items: const [
                      DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                      DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                    ],
                    onChanged: (v) => setState(() => _trendGranularity = v ?? 'Daily'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 260,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Colors.black.withValues(alpha: 0.06),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      interval: 25,
                      getTitlesWidget: (v, m) => Text(
                        _analyticsSafeIntAxisLabel(v),
                        style: TextStyle(fontSize: 11, color: AdminColors.muted.withValues(alpha: 0.8)),
                      ),
                    ),
                    axisNameWidget: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        'Detections',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AdminColors.muted.withValues(alpha: 0.75)),
                      ),
                    ),
                    axisNameSize: 18,
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (v, m) {
                        final i = _analyticsSafeAxisIndex(v, _trendLabels.length - 1);
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _trendLabels[i],
                            style: TextStyle(fontSize: 10, color: AdminColors.muted.withValues(alpha: 0.85)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touched) {
                      return touched.map((e) {
                        final xi = _analyticsSafeAxisIndex(e.x, _trendLabels.length - 1);
                        final yi = e.y.isFinite ? e.y.round() : 0;
                        return LineTooltipItem(
                          '${_trendLabels[xi]}\n$yi',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _trendSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AdminColors.statBlue,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                        radius: 5,
                        color: Colors.white,
                        strokeWidth: 2.5,
                        strokeColor: AdminColors.statBlue,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AdminColors.statBlue.withValues(alpha: 0.22),
                          AdminColors.statBlue.withValues(alpha: 0.02),
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
          Row(
            children: [
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: AdminColors.statBlue, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('COTS Detections', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminColors.muted.withValues(alpha: 0.9))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _distributionCard() {
    const colors = [
      AdminColors.statBlue,
      AdminColors.statGreen,
      AdminColors.statYellow,
      AdminColors.statPurple,
      Color(0xFF90A4AE),
    ];
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'COTS Distribution by Zone',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AdminColors.headerTitle),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
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
                          centerSpaceRadius: 58,
                          sections: _donutSections,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '248',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AdminColors.headerTitle),
                          ),
                          Text(
                            'Total',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AdminColors.muted.withValues(alpha: 0.85)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < _donutLegend.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AdminColors.headerTitle.withValues(alpha: 0.9),
                                    decoration: TextDecoration.none,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '${_donutLegend[i].$1}: ',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                    TextSpan(
                                      text: '${_donutLegend[i].$2} (${_donutLegend[i].$3})',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
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

  Widget _severityBarCard() {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Detections by Severity',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AdminColors.headerTitle),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 120,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 30,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Colors.black.withValues(alpha: 0.06),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: 30,
                      getTitlesWidget: (v, m) => Text(
                        _analyticsSafeIntAxisLabel(v),
                        style: TextStyle(fontSize: 10, color: AdminColors.muted.withValues(alpha: 0.75)),
                      ),
                    ),
                    axisNameWidget: Text(
                      'Detections',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AdminColors.muted.withValues(alpha: 0.75)),
                    ),
                    axisNameSize: 16,
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, m) {
                        const labels = ['High', 'Medium', 'Low'];
                        if (!v.isFinite) return const SizedBox.shrink();
                        final i = v.round();
                        if (i < 0 || i > 2) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(labels[i], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: 98,
                        width: 36,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        color: AdminColors.statRed,
                        backDrawRodData: BackgroundBarChartRodData(show: true, toY: 120, color: const Color(0xFFF0F4F8)),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: 92,
                        width: 36,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        color: AdminColors.statYellow,
                        backDrawRodData: BackgroundBarChartRodData(show: true, toY: 120, color: const Color(0xFFF0F4F8)),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [
                      BarChartRodData(
                        toY: 58,
                        width: 36,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        color: AdminColors.statGreen,
                        backDrawRodData: BackgroundBarChartRodData(show: true, toY: 120, color: const Color(0xFFF0F4F8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confidenceCard() {
    final rows = <(String, int, double, String, Color)>[
      ('High (≥ 80%)', 182, 0.734, 'Reliable detections with high visibility and clarity.', AdminColors.statGreen),
      ('Medium (50% – 79%)', 48, 0.194, 'Moderate confidence, review if necessary.', AdminColors.statYellow),
      ('Low (< 50%)', 18, 0.072, 'Low confidence detections, requiring verification.', AdminColors.statRed),
    ];
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Confidence Level Summary',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AdminColors.headerTitle),
          ),
          const SizedBox(height: 12),
          AdminDataTableScrollArea(
            tableWidth: AdminDataTableColumn.totalWidth(_confidenceSummaryColumns),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AdminDataTableHeader(columns: _confidenceSummaryColumns),
                for (final r in rows)
                  AdminDataTableStaticRow(
                    columnWidths: AdminDataTableColumn.widthsMap(_confidenceSummaryColumns),
                    showShadow: false,
                    cells: [
                      AdminDataTableCells.cell(
                        height: 58,
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: r.$5, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                r.$1,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Color(0xFF334155),
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AdminDataTableCells.cell(
                        height: 58,
                        align: TextAlign.right,
                        child: Text(
                          '${r.$2}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      AdminDataTableCells.cell(
                        height: 58,
                        align: TextAlign.right,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 112,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${(r.$3 * 100).toStringAsFixed(1)}%',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Color(0xFF1E293B),
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: r.$3,
                                    minHeight: 6,
                                    backgroundColor: r.$5.withValues(alpha: 0.14),
                                    valueColor: AlwaysStoppedAnimation<Color>(r.$5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      AdminDataTableCells.cell(
                        height: 58,
                        child: Text(
                          r.$4,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: AdminColors.muted.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _whiteCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InsightCard extends StatefulWidget {
  const _InsightCard({
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.valueColor,
    required this.subtext,
    required this.subtextColor,
    required this.footer,
    required this.footerIcon,
  });

  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final Color? valueColor;
  final String subtext;
  final Color subtextColor;
  final String footer;
  final bool footerIcon;

  @override
  State<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<_InsightCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hover ? 0.1 : 0.06),
              blurRadius: _hover ? 22 : 16,
              offset: Offset(0, _hover ? 8 : 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: widget.iconBg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(widget.icon, color: widget.iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AdminColors.headerTitle),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: widget.valueColor ?? AdminColors.headerTitle,
              ),
            ),
            if (widget.subtext.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                widget.subtext,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: widget.subtextColor),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.footerIcon) ...[
                  Icon(Icons.info_outline_rounded, size: 14, color: AdminColors.muted.withValues(alpha: 0.65)),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    widget.footer,
                    style: TextStyle(fontSize: 11.5, color: AdminColors.muted.withValues(alpha: 0.88), height: 1.35),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
