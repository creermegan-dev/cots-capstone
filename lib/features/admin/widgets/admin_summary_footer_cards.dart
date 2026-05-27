import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

class AdminSummaryFooterCards extends StatelessWidget {
  const AdminSummaryFooterCards({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 720;
        final row = [
          _mini(
            icon: Icons.flag_outlined,
            color: AdminColors.statRed,
            title: 'Recommended Actions',
            body: 'Total COTS to eliminate: 33',
          ),
          _mini(
            icon: Icons.place_outlined,
            color: AdminColors.statBlue,
            title: 'Zones Needing Action',
            body: '4 require immediate attention',
          ),
          _mini(
            icon: Icons.check_circle_outline_rounded,
            color: AdminColors.statGreen,
            title: 'Cleared This Week',
            body: '2 zones successfully cleared',
          ),
        ];
        if (narrow) {
          return Column(
            children: [
              row[0],
              const SizedBox(height: 12),
              row[1],
              const SizedBox(height: 12),
              row[2],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: row[0]),
            const SizedBox(width: 12),
            Expanded(child: row[1]),
            const SizedBox(width: 12),
            Expanded(child: row[2]),
          ],
        );
      },
    );
  }

  static Widget _mini({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.muted.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AdminColors.headerTitle,
                    height: 1.25,
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
