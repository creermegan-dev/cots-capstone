import 'package:flutter/material.dart';

import '../layout/admin_breakpoints.dart';
import '../theme/admin_theme.dart';
import '../widgets/map_monitoring/map_monitoring_analytics_panel.dart';
import '../widgets/map_monitoring/map_monitoring_bottom_section.dart';
import '../widgets/map_monitoring/map_monitoring_data.dart';
import '../widgets/map_monitoring/map_monitoring_filters.dart';
import '../widgets/map_monitoring/map_monitoring_header.dart';
import '../widgets/map_monitoring/map_monitoring_map.dart';

/// GIS-style map workspace for the admin shell (index **Map Monitoring**).
class AdminMapMonitoringScreen extends StatefulWidget {
  const AdminMapMonitoringScreen({super.key});

  @override
  State<AdminMapMonitoringScreen> createState() => _AdminMapMonitoringScreenState();
}

class _AdminMapMonitoringScreenState extends State<AdminMapMonitoringScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fade;

  String _zoneFilter = 'All Zones';
  String _statusFilter = 'All Status';
  String _riskFilter = 'All Risk Levels';
  String _densityFilter = 'All Density Levels';

  MapMonitoringViewMode _viewMode = MapMonitoringViewMode.mapViewing;
  bool _zoneBoundaries = true;
  bool _densityHeatmap = false;
  bool _zoneLabels = true;
  bool _satelliteView = true;
  bool _removalRecordsLayer = false;
  int _mapRefreshGeneration = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime(2026, 5, 18);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime(2027, 12, 31),
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 6)),
        end: now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AdminColors.statBlue,
              surface: Colors.white,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Demo filter: ${picked.start.toLocal()} → ${picked.end.toLocal()}',
          ),
        ),
      );
    }
  }

  void _resetLayers() {
    setState(() {
      _zoneBoundaries = true;
      _densityHeatmap = false;
      _zoneLabels = true;
      _satelliteView = true;
      _removalRecordsLayer = false;
      _viewMode = MapMonitoringViewMode.mapViewing;
    });
  }

  void _refreshMonitoringView() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Monitoring layers refreshed (demo).'),
      ),
    );
    setState(() => _mapRefreshGeneration++);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final wide = w >= AdminBreakpoints.contentWide;
          final basePad = AdminBreakpoints.pagePadding(w);
          final pad = EdgeInsets.fromLTRB(basePad.left, 22, basePad.right, 22);
          final mapH = wide ? 480.0 : (w < AdminBreakpoints.mobile ? 320.0 : 400.0);

          return SingleChildScrollView(
            padding: pad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MapMonitoringHeader(
                  onDateRangeTap: _pickDateRange,
                  onRefreshTap: _refreshMonitoringView,
                ),
                const SizedBox(height: 22),
                MapMonitoringFilters(
                  zoneFilter: _zoneFilter,
                  statusFilter: _statusFilter,
                  riskFilter: _riskFilter,
                  densityFilter: _densityFilter,
                  onZoneChanged: (v) => setState(() => _zoneFilter = v ?? _zoneFilter),
                  onStatusChanged: (v) => setState(() => _statusFilter = v ?? _statusFilter),
                  onRiskChanged: (v) => setState(() => _riskFilter = v ?? _riskFilter),
                  onDensityChanged: (v) => setState(() => _densityFilter = v ?? _densityFilter),
                ),
                const SizedBox(height: 18),
                if (wide)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MapMonitoringMap(
                        key: ValueKey<int>(_mapRefreshGeneration),
                        mapHeight: mapH,
                        viewMode: _viewMode,
                        onViewModeChanged: (m) => setState(() => _viewMode = m),
                        showZonePolygons: _zoneBoundaries,
                        densityHeatmapEnabled: _densityHeatmap,
                        showLabels: _zoneLabels,
                        useSatelliteTiles: _satelliteView,
                        showRemovalRecords: _removalRecordsLayer,
                      ),
                      const SizedBox(height: 18),
                      MapMonitoringAnalyticsPanel(
                        zoneBoundaries: _zoneBoundaries,
                        densityHeatmap: _densityHeatmap,
                        densityLayers: _viewMode == MapMonitoringViewMode.densityLayers,
                        zoneLabels: _zoneLabels,
                        satelliteView: _satelliteView,
                        removalRecords: _removalRecordsLayer,
                        onZoneBoundariesChanged: (v) => setState(() => _zoneBoundaries = v),
                        onDensityHeatmapChanged: (v) => setState(() => _densityHeatmap = v),
                        onDensityLayersChanged: (v) => setState(() {
                          if (v) {
                            _viewMode = MapMonitoringViewMode.densityLayers;
                          } else if (_viewMode == MapMonitoringViewMode.densityLayers) {
                            _viewMode = MapMonitoringViewMode.mapViewing;
                          }
                        }),
                        onZoneLabelsChanged: (v) => setState(() => _zoneLabels = v),
                        onSatelliteViewChanged: (v) => setState(() => _satelliteView = v),
                        onRemovalRecordsChanged: (v) => setState(() => _removalRecordsLayer = v),
                        onResetLayers: _resetLayers,
                      ),
                    ],
                  )
                else ...[
                  MapMonitoringMap(
                    key: ValueKey<int>(_mapRefreshGeneration),
                    mapHeight: mapH,
                    viewMode: _viewMode,
                    onViewModeChanged: (m) => setState(() => _viewMode = m),
                    showZonePolygons: _zoneBoundaries,
                    densityHeatmapEnabled: _densityHeatmap,
                    showLabels: _zoneLabels,
                    useSatelliteTiles: _satelliteView,
                    showRemovalRecords: _removalRecordsLayer,
                  ),
                  const SizedBox(height: 18),
                  MapMonitoringAnalyticsPanel(
                    zoneBoundaries: _zoneBoundaries,
                    densityHeatmap: _densityHeatmap,
                    densityLayers: _viewMode == MapMonitoringViewMode.densityLayers,
                    zoneLabels: _zoneLabels,
                    satelliteView: _satelliteView,
                    removalRecords: _removalRecordsLayer,
                    onZoneBoundariesChanged: (v) => setState(() => _zoneBoundaries = v),
                    onDensityHeatmapChanged: (v) => setState(() => _densityHeatmap = v),
                    onDensityLayersChanged: (v) => setState(() {
                      if (v) {
                        _viewMode = MapMonitoringViewMode.densityLayers;
                      } else if (_viewMode == MapMonitoringViewMode.densityLayers) {
                        _viewMode = MapMonitoringViewMode.mapViewing;
                      }
                    }),
                    onZoneLabelsChanged: (v) => setState(() => _zoneLabels = v),
                    onSatelliteViewChanged: (v) => setState(() => _satelliteView = v),
                    onRemovalRecordsChanged: (v) => setState(() => _removalRecordsLayer = v),
                    onResetLayers: _resetLayers,
                  ),
                ],
                const SizedBox(height: 22),
                const MapMonitoringBottomSection(),
                const SizedBox(height: 28),
              ],
            ),
          );
        },
      ),
    );
  }
}
