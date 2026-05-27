import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

/// Donut chart — COTS by status (mock).
class CotsStatusDonutCard extends StatelessWidget {
  const CotsStatusDonutCard({super.key});

  @override
  Widget build(BuildContext context) {
    const total = 520.0;
    const active = 249.6; // 48%
    const scheduled = 124.8; // 24%
    const cleared = 145.6; // 28%

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'COTS by Status',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AdminColors.headerTitle,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 52,
                      sections: [
                        PieChartSectionData(
                          value: active,
                          color: AdminColors.statRed.withValues(alpha: 0.9),
                          radius: 44,
                          title: '48%',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        PieChartSectionData(
                          value: scheduled,
                          color: AdminColors.statYellow.withValues(alpha: 0.95),
                          radius: 44,
                          title: '24%',
                          titleStyle: const TextStyle(
                            color: Color(0xFF5D4037),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        PieChartSectionData(
                          value: cleared,
                          color: AdminColors.statGreen.withValues(alpha: 0.9),
                          radius: 44,
                          title: '28%',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${total.toInt()}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AdminColors.headerTitle,
                        ),
                      ),
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 13,
                          color: AdminColors.muted.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _legend('Active', '248', '48%', AdminColors.statRed),
                      _legend('Scheduled', '125', '24%', AdminColors.statYellow),
                      _legend('Cleared', '146', '28%', AdminColors.statGreen),
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

  static Widget _legend(String label, String count, String pct, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ),
          Text(
            '$count · $pct',
            style: TextStyle(
              fontSize: 12,
              color: AdminColors.muted.withValues(alpha: 0.95),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
