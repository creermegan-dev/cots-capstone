import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

/// Mock line chart — expert-validated COTS detections over time.
class DetectionsLineChartCard extends StatefulWidget {
  const DetectionsLineChartCard({super.key});

  @override
  State<DetectionsLineChartCard> createState() => _DetectionsLineChartCardState();
}

class _DetectionsLineChartCardState extends State<DetectionsLineChartCard> {
  String _range = 'This Week';

  static const _labels = ['May 12', 'May 13', 'May 14', 'May 15', 'May 16', 'May 17', 'May 18'];

  List<FlSpot> get _spots {
    switch (_range) {
      case 'This Month':
        return List.generate(10, (i) => FlSpot(i.toDouble(), 18 + (i * 6.0 % 48)));
      case 'This Year':
        return List.generate(12, (i) => FlSpot(i.toDouble(), 12 + (i * 9 % 58)));
      default:
        // Expert-validated detection counts (mock trend).
        return const [
          FlSpot(0, 24),
          FlSpot(1, 31),
          FlSpot(2, 28),
          FlSpot(3, 36),
          FlSpot(4, 42),
          FlSpot(5, 38),
          FlSpot(6, 33),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
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
                      'Validated COTS Detections Over Time',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.headerTitle,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Trends based on expert-validated detection records only',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _range,
                  borderRadius: BorderRadius.circular(12),
                  items: const [
                    DropdownMenuItem(value: 'This Week', child: Text('This Week')),
                    DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                    DropdownMenuItem(value: 'This Year', child: Text('This Year')),
                  ],
                  onChanged: (v) => setState(() => _range = v ?? 'This Week'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Colors.black.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 25,
                      getTitlesWidget: (v, m) => Text(
                        v.toInt().toString(),
                        style: TextStyle(fontSize: 10, color: AdminColors.muted.withValues(alpha: 0.8)),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (v, m) {
                        final i = v.toInt().clamp(0, _labels.length - 1);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _range == 'This Week' ? _labels[i] : '${v.toInt()}',
                            style: TextStyle(fontSize: 10, color: AdminColors.muted.withValues(alpha: 0.85)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AdminColors.statBlue,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: AdminColors.statBlue,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AdminColors.statBlue.withValues(alpha: 0.25),
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
        ],
      ),
    );
  }
}
