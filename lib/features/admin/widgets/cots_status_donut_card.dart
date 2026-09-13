import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

/// Donut chart — COTS by validation / intervention status (mock).
class CotsStatusDonutCard extends StatelessWidget {
  const CotsStatusDonutCard({super.key});

  @override
  Widget build(BuildContext context) {
    const total = 520.0;
    const pending = 140.4; // 27%
    const validated = 192.4; // 37%
    const intervention = 93.6; // 18%
    const cleared = 93.6; // 18%

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
            height: 220,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 48,
                      sections: [
                        PieChartSectionData(
                          value: pending,
                          color: AdminColors.statYellow.withValues(alpha: 0.95),
                          radius: 42,
                          title: '27%',
                          titleStyle: const TextStyle(
                            color: Color(0xFF5D4037),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                        PieChartSectionData(
                          value: validated,
                          color: AdminColors.statBlue.withValues(alpha: 0.9),
                          radius: 42,
                          title: '37%',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                        PieChartSectionData(
                          value: intervention,
                          color: AdminColors.statRed.withValues(alpha: 0.9),
                          radius: 42,
                          title: '18%',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                        PieChartSectionData(
                          value: cleared,
                          color: AdminColors.statGreen.withValues(alpha: 0.9),
                          radius: 42,
                          title: '18%',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${total.toInt()}',
                        style: const TextStyle(
                          fontSize: 26,
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
                      const SizedBox(height: 12),
                      _legend('Pending Validation', '140', '27%', AdminColors.statYellow),
                      _legend('Validated', '192', '37%', AdminColors.statBlue),
                      _legend('Intervention Required', '94', '18%', AdminColors.statRed),
                      _legend('Cleared', '94', '18%', AdminColors.statGreen),
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
      padding: const EdgeInsets.only(bottom: 8),
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
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5),
            ),
          ),
          Text(
            '$count · $pct',
            style: TextStyle(
              fontSize: 11,
              color: AdminColors.muted.withValues(alpha: 0.95),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
