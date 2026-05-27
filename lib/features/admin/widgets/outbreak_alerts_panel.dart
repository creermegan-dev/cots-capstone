import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

class OutbreakAlertsPanel extends StatelessWidget {
  const OutbreakAlertsPanel({super.key});

  static const _alerts = [
    _Alert(
      zone: 'Zone A — North Reef',
      density: '25 COTS / ha',
      action: 'Deploy response team within 24h',
      when: '10 min ago',
    ),
    _Alert(
      zone: 'Zone B — East shoal',
      density: '18 COTS / ha',
      action: 'Schedule controlled removal',
      when: '2 hr ago',
    ),
    _Alert(
      zone: 'Zone F — Survey grid 4',
      density: '31 COTS / ha',
      action: 'Escalate to marine park authority',
      when: 'Yesterday',
    ),
  ];

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
          const Text(
            'Outbreak Alerts',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AdminColors.headerTitle,
            ),
          ),
          const SizedBox(height: 14),
          ..._alerts.map((a) => _tile(a)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              label: const Text('Manage Alerts'),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _tile(_Alert a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.statRed.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: AdminColors.statRed.withValues(alpha: 0.9)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.zone,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AdminColors.headerTitle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  a.density,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AdminColors.statRed.withValues(alpha: 0.95),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  a.action,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AdminColors.muted.withValues(alpha: 0.95),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Text(
            a.when,
            style: TextStyle(
              fontSize: 11,
              color: AdminColors.muted.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Alert {
  const _Alert({
    required this.zone,
    required this.density,
    required this.action,
    required this.when,
  });

  final String zone;
  final String density;
  final String action;
  final String when;
}
