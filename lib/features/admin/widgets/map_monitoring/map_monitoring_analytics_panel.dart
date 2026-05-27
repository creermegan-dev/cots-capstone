import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../theme/admin_theme.dart';
import 'map_monitoring_data.dart';

class MapMonitoringAnalyticsPanel extends StatelessWidget {
  const MapMonitoringAnalyticsPanel({
    super.key,
    required this.zoneBoundaries,
    required this.densityHeatmap,
    required this.densityLayers,
    required this.zoneLabels,
    required this.satelliteView,
    required this.removalRecords,
    required this.onZoneBoundariesChanged,
    required this.onDensityHeatmapChanged,
    required this.onDensityLayersChanged,
    required this.onZoneLabelsChanged,
    required this.onSatelliteViewChanged,
    required this.onRemovalRecordsChanged,
    required this.onResetLayers,
  });

  final bool zoneBoundaries;
  final bool densityHeatmap;
  final bool densityLayers;
  final bool zoneLabels;
  final bool satelliteView;
  final bool removalRecords;
  final ValueChanged<bool> onZoneBoundariesChanged;
  final ValueChanged<bool> onDensityHeatmapChanged;
  final ValueChanged<bool> onDensityLayersChanged;
  final ValueChanged<bool> onZoneLabelsChanged;
  final ValueChanged<bool> onSatelliteViewChanged;
  final ValueChanged<bool> onRemovalRecordsChanged;
  final VoidCallback onResetLayers;

  static const double _cardRowGap = 14;
  /// Minimum width to show all three cards in one row with equal [Expanded] slots.
  static const double _threeColumnMinWidth = 900;
  /// Minimum width for two cards on the first row (tablet).
  static const double _twoColumnMinWidth = 520;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, outer) {
        final w = outer.maxWidth;

        if (w >= _threeColumnMinWidth) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _densityOverviewCard()),
                const SizedBox(width: _cardRowGap),
                Expanded(child: _realtimeSummaryCard()),
                const SizedBox(width: _cardRowGap),
                Expanded(child: _mapLayersCard()),
              ],
            ),
          );
        }

        if (w >= _twoColumnMinWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _densityOverviewCard()),
                    const SizedBox(width: _cardRowGap),
                    Expanded(child: _realtimeSummaryCard()),
                  ],
                ),
              ),
              const SizedBox(height: _cardRowGap),
              _mapLayersCard(),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _densityOverviewCard(),
            const SizedBox(height: _cardRowGap),
            _realtimeSummaryCard(),
            const SizedBox(height: _cardRowGap),
            _mapLayersCard(),
          ],
        );
      },
    );
  }

  Widget _densityOverviewCard() {
    const d = MapMonitoringMock.densityOverview;
    final total = (d.high + d.moderate + d.low + d.noData).toDouble();

    return _whiteShell(
      child: Align(
        alignment: Alignment.topLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Density Overview',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AdminColors.headerTitle,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, box) {
                final narrow = box.maxWidth < 300;
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 172,
                        child: Center(
                          child: _DensityPieChart(d: d, total: total, maxBoxSide: 168),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _DensityLegendTable(d: d),
                    ],
                  );
                }
                return SizedBox(
                  height: 220,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 46,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 6, 0),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _DensityPieChart(d: d, total: total, maxBoxSide: 200),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 54,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _DensityLegendTable(d: d),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _realtimeSummaryCard() {
    return _whiteShell(
      child: Align(
        alignment: Alignment.topLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Real-time Summary',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AdminColors.headerTitle,
              ),
            ),
            const SizedBox(height: 12),
            _summaryRow('Total Zones', '${MapMonitoringMock.summary.totalZones}'),
            _summaryRow('Active (High Risk)', '${MapMonitoringMock.summary.activeHighRisk}'),
            _summaryRow(
              'Average Density',
              '${MapMonitoringMock.summary.avgDensity.toStringAsFixed(2)} COTS/ha',
            ),
            _summaryRow(
              'Total COTS Detected',
              '${MapMonitoringMock.summary.totalCotsDetected}',
            ),
            _summaryRow('Last Updated', MapMonitoringMock.lastUpdated),
          ],
        ),
      ),
    );
  }

  Widget _mapLayersCard() {
    return _whiteShell(
      child: Align(
        alignment: Alignment.topLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Map Layers',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AdminColors.headerTitle,
              ),
            ),
            const SizedBox(height: 8),
            _tileCheckbox(
              'Zone Boundaries',
              zoneBoundaries,
              onZoneBoundariesChanged,
            ),
            _tileCheckbox(
              'Density Heatmap',
              densityHeatmap,
              onDensityHeatmapChanged,
            ),
            _tileCheckbox(
              'Density Layers',
              densityLayers,
              onDensityLayersChanged,
            ),
            _tileCheckbox(
              'Zone Labels',
              zoneLabels,
              onZoneLabelsChanged,
            ),
            _tileCheckbox(
              'Satellite View',
              satelliteView,
              onSatelliteViewChanged,
            ),
            _tileCheckbox(
              'Removal Records',
              removalRecords,
              onRemovalRecordsChanged,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onResetLayers,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminColors.statBlue,
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Reset Layers',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _whiteShell({required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
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

  static Widget _summaryRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              k,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AdminColors.muted.withValues(alpha: 0.95),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AdminColors.headerTitle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _tileCheckbox(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: value,
                    activeColor: AdminColors.statBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (v) => onChanged(v ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.headerTitle,
                    ),
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

/// Donut for density overview — slice order matches [_DensityLegendTable] (clockwise from top).
class _DensityPieChart extends StatelessWidget {
  const _DensityPieChart({
    required this.d,
    required this.total,
    required this.maxBoxSide,
  });

  final ({int high, int moderate, int low, int noData}) d;
  final double total;
  final double maxBoxSide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: LayoutBuilder(
        builder: (context, c) {
          final side =
              (c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight).clamp(72.0, maxBoxSide);
          const ringRadius = 36.0;
          return SizedBox(
            width: side,
            height: side,
            child: PieChart(
              PieChartData(
                startDegreeOffset: -90,
                sectionsSpace: 2,
                centerSpaceRadius: 44,
                sections: [
                  PieChartSectionData(
                    value: d.low.toDouble(),
                    color: AdminColors.statGreen.withValues(alpha: 0.9),
                    radius: ringRadius,
                    title: '${((d.low / total) * 100).round()}%',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                  PieChartSectionData(
                    value: d.noData.toDouble(),
                    color: AdminColors.muted.withValues(alpha: 0.45),
                    radius: ringRadius,
                    title: '${((d.noData / total) * 100).round()}%',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                  PieChartSectionData(
                    value: d.high.toDouble(),
                    color: AdminColors.statRed.withValues(alpha: 0.92),
                    radius: ringRadius,
                    title: '${((d.high / total) * 100).round()}%',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                  PieChartSectionData(
                    value: d.moderate.toDouble(),
                    color: AdminColors.statYellow.withValues(alpha: 0.95),
                    radius: ringRadius,
                    title: '${((d.moderate / total) * 100).round()}%',
                    titleStyle: const TextStyle(
                      color: Color(0xFF5D4037),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DensityLegendTable extends StatelessWidget {
  const _DensityLegendTable({required this.d});

  final ({int high, int moderate, int low, int noData}) d;

  static const TextStyle _labelStyle = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: AdminColors.headerTitle,
    height: 1.28,
  );

  static const TextStyle _valueStyle = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w800,
    color: AdminColors.headerTitle,
    height: 1.28,
  );

  TableRow _row(String label, int value, Color dotColor) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 9, 10, 9),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: _labelStyle,
              softWrap: true,
              maxLines: 2,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 9, 2, 9),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text('$value', style: _valueStyle, textAlign: TextAlign.right),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(24),
        1: FlexColumnWidth(1),
        2: FixedColumnWidth(40),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _row('Low', d.low, AdminColors.statGreen),
        _row('No Detection', d.noData, AdminColors.muted),
        _row('High', d.high, AdminColors.statRed),
        _row('Moderate', d.moderate, AdminColors.statYellow),
      ],
    );
  }
}
