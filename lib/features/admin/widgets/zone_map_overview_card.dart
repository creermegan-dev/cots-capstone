import 'package:flutter/material.dart';

import '../layout/admin_breakpoints.dart';
import '../theme/admin_theme.dart';
import 'map_monitoring/map_monitoring_data.dart';
import 'map_monitoring/map_monitoring_map.dart';

/// Dashboard zone map — same flutter_map workspace as [MapMonitoringMap].
class ZoneMapOverviewCard extends StatefulWidget {
  const ZoneMapOverviewCard({super.key, this.onExpandMap});

  final VoidCallback? onExpandMap;

  @override
  State<ZoneMapOverviewCard> createState() => _ZoneMapOverviewCardState();
}

class _ZoneMapOverviewCardState extends State<ZoneMapOverviewCard> {
  MapMonitoringViewMode _viewMode = MapMonitoringViewMode.mapViewing;

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
              const Text(
                'GIS Map Overview',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.headerTitle,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: widget.onExpandMap,
                icon: const Icon(Icons.open_in_full_rounded, size: 18),
                label: const Text('Expand Map'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Interactive reef zone map with validated COTS detection locations.',
            style: TextStyle(
              fontSize: 12.5,
              color: AdminColors.muted.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _InfestationLegendDot(
                color: AdminColors.statGreen,
                label: 'Green = Low infestation',
              ),
              _InfestationLegendDot(
                color: AdminColors.statYellow,
                label: 'Yellow = Moderate infestation',
              ),
              _InfestationLegendDot(
                color: AdminColors.statRed,
                label: 'Red = High infestation',
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final mapH = w >= AdminBreakpoints.contentWide
                  ? 480.0
                  : (w < AdminBreakpoints.mobile ? 320.0 : 400.0);

              return MapMonitoringMap(
                mapHeight: mapH,
                viewMode: _viewMode,
                onViewModeChanged: (mode) => setState(() => _viewMode = mode),
                showZonePolygons: true,
                densityHeatmapEnabled: false,
                showLabels: true,
                useSatelliteTiles: true,
                onFullscreenTap: widget.onExpandMap,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InfestationLegendDot extends StatelessWidget {
  const _InfestationLegendDot({required this.color, required this.label});

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
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AdminColors.headerTitle,
          ),
        ),
      ],
    );
  }
}
