import 'package:flutter/material.dart';

import '../../layout/admin_breakpoints.dart';
import '../../theme/admin_theme.dart';
import '../admin_data_table.dart';
import 'map_monitoring_data.dart';

const List<AdminDataTableColumn> _highRiskTableColumns = [
  AdminDataTableColumn('#', 44, headerAlign: TextAlign.center),
  AdminDataTableColumn('Zone Name', 200),
  AdminDataTableColumn('Avg. Density', 140, headerAlign: TextAlign.right),
  AdminDataTableColumn('Risk Level', 112, headerAlign: TextAlign.center),
  AdminDataTableColumn('Status', 120, headerAlign: TextAlign.center),
  AdminDataTableColumn('Last Monitoring', 172),
];

List<TableCell> _highRiskRowCells(int index, HighRiskTableRow r) {
  return [
    AdminDataTableCells.text('$index', align: TextAlign.center),
    AdminDataTableCells.cell(
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: r.risk.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              r.zoneName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ),
        ],
      ),
    ),
    AdminDataTableCells.text(
      '${r.avgDensity.toStringAsFixed(1)} COTS/ha',
      align: TextAlign.right,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
    ),
    AdminDataTableCells.cell(
      align: TextAlign.center,
      child: AdminDataTableBadge(
        label: r.risk.label,
        foreground: r.risk.color,
        background: r.risk.color.withValues(alpha: 0.13),
      ),
    ),
    AdminDataTableCells.cell(
      align: TextAlign.center,
      child: AdminDataTableBadge(
        label: r.status,
        foreground: r.risk.color,
        background: r.risk.color.withValues(alpha: 0.14),
      ),
    ),
    AdminDataTableCells.text(
      r.lastMonitoring,
      style: TextStyle(fontSize: 12, color: AdminColors.muted.withValues(alpha: 0.95)),
    ),
  ];
}

class MapMonitoringBottomSection extends StatelessWidget {
  const MapMonitoringBottomSection({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final stack = c.maxWidth < AdminBreakpoints.desktop;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _HighRiskTableCard(),
              const SizedBox(height: 16),
              const _RecentAlertsCard(),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(flex: 58, child: _HighRiskTableCard()),
            const SizedBox(width: 18),
            const Expanded(flex: 42, child: _RecentAlertsCard()),
          ],
        );
      },
    );
  }
}

class _HighRiskTableCard extends StatelessWidget {
  const _HighRiskTableCard();

  @override
  Widget build(BuildContext context) {
    return _shadowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'High Risk Zones',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.headerTitle,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'View All',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AdminDataTableScrollArea(
            tableWidth: AdminDataTableColumn.totalWidth(_highRiskTableColumns),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminDataTableHeader(columns: _highRiskTableColumns),
                for (var i = 0; i < MapMonitoringMock.highRiskRows.length; i++)
                  AdminDataTableStaticRow(
                    columnWidths: AdminDataTableColumn.widthsMap(_highRiskTableColumns),
                    cells: _highRiskRowCells(i + 1, MapMonitoringMock.highRiskRows[i]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

class _RecentAlertsCard extends StatelessWidget {
  const _RecentAlertsCard();

  @override
  Widget build(BuildContext context) {
    return _shadowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Recent Alerts',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.headerTitle,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'View All',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...MapMonitoringMock.alerts.map(_alertTile),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              label: const Text(
                'Manage Alerts',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertTile(MapAlertItem a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AdminColors.contentBg.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AdminColors.statRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AdminColors.statRed,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.zoneName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AdminColors.headerTitle,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        a.message,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AdminColors.muted.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        a.timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.statBlue.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _shadowCard({required Widget child}) {
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
    child: child,
  );
}
