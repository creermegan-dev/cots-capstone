import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../models/cots_marine_sector_palette.dart';
import '../../../../models/davao_gulf_geography.dart';
import '../../../../widgets/marine_sector_map_label.dart';
import '../../theme/admin_theme.dart';
import 'map_monitoring_constants.dart';
import 'map_monitoring_data.dart';

class MapMonitoringMap extends StatefulWidget {
  const MapMonitoringMap({
    super.key,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.showZonePolygons,
    required this.densityHeatmapEnabled,
    required this.showLabels,
    required this.useSatelliteTiles,
    this.showRemovalRecords = false,
    this.mapHeight = 460,
    this.onFullscreenTap,
  });

  final MapMonitoringViewMode viewMode;
  final ValueChanged<MapMonitoringViewMode> onViewModeChanged;
  final bool showZonePolygons;
  final bool densityHeatmapEnabled;
  final bool showLabels;
  final bool useSatelliteTiles;
  final bool showRemovalRecords;
  final double mapHeight;
  /// When set, shows a "View Fullscreen" control on the map (not in the page header).
  final VoidCallback? onFullscreenTap;

  @override
  State<MapMonitoringMap> createState() => _MapMonitoringMapState();
}

class _MapMonitoringMapState extends State<MapMonitoringMap> {
  final MapController _controller = MapController();
  double _mapZoom = 10;
  String? _selectedZoneCode;

  static const _userAgent = 'cots_monitor';
  static const _overviewZoomCutoff = 10.2;
  static const _gulfOverview = LatLng(7.06, 125.68);

  bool get _isDrilledIn => _selectedZoneCode != null;

  bool get _marineSectorView =>
      _isDrilledIn &&
      DavaoGulfGeography.municipalityByZoneCode(_selectedZoneCode!)
              ?.marineSectorLayout ==
          true;

  List<MonitoringZone> get _visibleZones {
    if (_isDrilledIn) {
      return MapMonitoringMock.barangaysForZone(_selectedZoneCode!);
    }
    return MapMonitoringMock.zones;
  }

  void _drillIntoZone(String zoneCode) {
    final sites = MapMonitoringMock.barangaysForZone(zoneCode);
    if (sites.isEmpty) return;

    if (zoneCode == 'A') {
      _controller.move(
        DavaoGulfGeography.panaboMarineSectorCenter,
        DavaoGulfGeography.panaboMarineSectorZoom,
      );
      setState(() {
        _selectedZoneCode = zoneCode;
        _mapZoom = DavaoGulfGeography.panaboMarineSectorZoom;
      });
      return;
    }

    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final site in sites) {
      for (final p in site.polygon) {
        minLat = math.min(minLat, p.latitude);
        maxLat = math.max(maxLat, p.latitude);
        minLng = math.min(minLng, p.longitude);
        maxLng = math.max(maxLng, p.longitude);
      }
    }
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    const drillZoom = 12.8;
    _controller.move(center, drillZoom);
    setState(() {
      _selectedZoneCode = zoneCode;
      _mapZoom = drillZoom;
    });
  }

  void _backToZones() {
    _controller.move(_gulfOverview, 10);
    setState(() {
      _selectedZoneCode = null;
      _mapZoom = 10;
    });
  }

  List<CircleMarker> _heatmapCircles() {
    final siteMode = _isDrilledIn;
    final radii = siteMode
        ? const <double>[180, 95, 40]
        : const <double>[5200, 2800, 1200];
    final opacities = siteMode
        ? const <double>[0.18, 0.32, 0.52]
        : const <double>[0.14, 0.28, 0.48];
    final out = <CircleMarker>[];
    for (final z in _visibleZones) {
      final c = z.risk.color;
      final p = z.centroid;
      for (var i = 0; i < radii.length; i++) {
        out.add(
          CircleMarker(
            point: p,
            radius: radii[i],
            useRadiusInMeter: true,
            color: c.withValues(alpha: opacities[i]),
            borderStrokeWidth: 0,
            borderColor: Colors.transparent,
          ),
        );
      }
    }
    return out;
  }

  List<CircleMarker> _densityCircles() {
    final radius = _isDrilledIn ? 160.0 : 4200.0;
    return _visibleZones
        .map(
          (z) => CircleMarker(
            point: z.centroid,
            radius: radius,
            useRadiusInMeter: true,
            color: z.risk.color.withValues(alpha: 0.18),
            borderStrokeWidth: 2,
            borderColor: z.risk.color,
          ),
        )
        .toList();
  }

  List<Polygon> _polygons() {
    return _visibleZones.map((z) {
      final isSite = !z.isMunicipality;
      if (_marineSectorView && isSite) {
        final accent = marineSectorColor(z.code);
        return Polygon(
          points: z.polygon,
          color: accent.withValues(alpha: 0.38),
          borderColor: accent,
          borderStrokeWidth: 1.8,
        );
      }
      final accent = z.risk.color;
      return Polygon(
        points: z.polygon,
        color: accent.withValues(alpha: isSite ? 0.28 : 0.36),
        borderColor: accent.withValues(alpha: 0.95),
        borderStrokeWidth: isSite ? 2.4 : 2,
      );
    }).toList();
  }

  List<Marker> _marineSectorLabels() {
    return _visibleZones
        .where((z) => !z.isMunicipality)
        .map(
          (z) => Marker(
            point: z.centroid,
            width: 72,
            height: 40,
            alignment: Alignment.center,
            child: MarineSectorMapLabel(siteCode: z.displayName),
          ),
        )
        .toList();
  }

  List<Marker> _markers() {
    return _visibleZones
        .map(
          (z) => Marker(
            point: z.centroid,
            width: z.isMunicipality ? 132 : 52,
            height: z.isMunicipality ? 78 : 52,
            alignment: Alignment.center,
            child: _ZoneMarkerCard(
              zone: z,
              showRemovalStats: widget.showRemovalRecords,
              compact: !z.isMunicipality,
              onTap: z.isMunicipality ? () => _drillIntoZone(z.code) : null,
            ),
          ),
        )
        .toList();
  }

  void _nudgeZoom(double delta) {
    final cam = _controller.camera;
    _controller.move(cam.center, cam.zoom + delta);
    setState(() => _mapZoom = cam.zoom + delta);
  }

  @override
  Widget build(BuildContext context) {
    final showHeatPrimary = !_marineSectorView &&
        (widget.viewMode == MapMonitoringViewMode.heatMap ||
            (widget.viewMode == MapMonitoringViewMode.mapViewing &&
                widget.densityHeatmapEnabled));
    final showDensityPrimary =
        !_marineSectorView && widget.viewMode == MapMonitoringViewMode.densityLayers;
    final useSatellite = widget.useSatelliteTiles || _marineSectorView;

    final layers = <Widget>[
      TileLayer(
        key: ValueKey<bool>(useSatellite),
        urlTemplate: useSatellite
            ? kAdminMapSatelliteTileUrl
            : kAdminMapStreetTileUrl,
        userAgentPackageName: _userAgent,
      ),
    ];

    if (showHeatPrimary) {
      layers.add(CircleLayer(circles: _heatmapCircles()));
    }
    if (showDensityPrimary) {
      layers.add(CircleLayer(circles: _densityCircles()));
    }

    if (widget.showZonePolygons || _isDrilledIn) {
      layers.add(PolygonLayer(polygons: _polygons()));
    }

    if (_marineSectorView) {
      layers.add(MarkerLayer(markers: _marineSectorLabels()));
    } else if (widget.showLabels) {
      layers.add(MarkerLayer(markers: _markers()));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.mapHeight,
        child: Stack(
          children: [
            RepaintBoundary(
              child: FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: const LatLng(7.06, 125.68),
                initialZoom: 10,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.scrollWheelZoom |
                      InteractiveFlag.doubleTapZoom,
                ),
                onPositionChanged: (pos, _) {
                  final z = pos.zoom;
                  if (z == null) return;
                  if ((z - _mapZoom).abs() < 0.01) return;
                  setState(() {
                    _mapZoom = z;
                    if (_isDrilledIn && z < _overviewZoomCutoff) {
                      _selectedZoneCode = null;
                    }
                  });
                },
              ),
              children: layers,
            ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapViewModeMenu(
                    mode: widget.viewMode,
                    onChanged: widget.onViewModeChanged,
                  ),
                  if (showHeatPrimary || showDensityPrimary) ...[
                    const SizedBox(height: 10),
                    const _DensityHeatLegend(),
                  ],
                  if (_marineSectorView) ...[
                    const SizedBox(height: 10),
                    const _MarineSectorLegend(),
                  ],
                ],
              ),
            ),
            if (_isDrilledIn)
              Positioned(
                right: 12,
                top: widget.onFullscreenTap != null ? 64 : 12,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.96),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _backToZones,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_rounded, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'All zones',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.onFullscreenTap != null)
              Positioned(
                right: 12,
                top: 12,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  shadowColor: Colors.black38,
                  color: Colors.transparent,
                  child: FilledButton.icon(
                    onPressed: widget.onFullscreenTap,
                    icon: const Icon(Icons.open_in_full_rounded, size: 18),
                    label: const Text('View Fullscreen'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminColors.statBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 12,
              bottom: 52,
              child: Column(
                children: [
                  _zoomButton(Icons.remove, () => _nudgeZoom(-0.6)),
                  const SizedBox(height: 8),
                  _zoomButton(Icons.add, () => _nudgeZoom(0.6)),
                  const SizedBox(height: 10),
                  _zoomButton(Icons.my_location_rounded, _backToZones),
                ],
              ),
            ),
            Positioned(
              right: 14,
              bottom: 14,
              child: _ScaleApproxBadge(zoom: _mapZoom),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: AdminColors.headerTitle),
        ),
      ),
    );
  }
}

class _MarineSectorLegend extends StatelessWidget {
  const _MarineSectorLegend();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Marine sectors',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AdminColors.muted,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in kMarineSectorColors.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: entry.value.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: entry.value, width: 1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.headerTitle,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DensityHeatLegend extends StatelessWidget {
  const _DensityHeatLegend();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Density layer',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AdminColors.muted,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            _row('Very High', '80–100', const Color(0xFFB71C1C)),
            _row('High', '60–79', AdminColors.statRed),
            _row('Moderate', '40–59', AdminColors.statYellow),
            _row('Low', '< 40', AdminColors.statGreen),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String range, Color swatch) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: swatch,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label · $range COTS/ha',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AdminColors.headerTitle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hover / scale is isolated here so panning the map does not rebuild [MapMonitoringMap]
/// (parent used to call `setState` on every marker enter/exit while the cursor moved).
class _ZoneMarkerCard extends StatefulWidget {
  const _ZoneMarkerCard({
    required this.zone,
    this.showRemovalStats = false,
    this.compact = false,
    this.onTap,
  });

  final MonitoringZone zone;
  final bool showRemovalStats;
  final bool compact;
  final VoidCallback? onTap;

  @override
  State<_ZoneMarkerCard> createState() => _ZoneMarkerCardState();
}

class _ZoneMarkerCardState extends State<_ZoneMarkerCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final z = widget.zone;
    if (widget.compact) {
      return MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Tooltip(
          message: z.fullName ?? z.displayName,
          child: AnimatedScale(
            scale: _hover ? 1.08 : 1,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.78),
                shape: BoxShape.circle,
                border: Border.all(
                  color: z.risk.color.withValues(alpha: _hover ? 1 : 0.9),
                  width: _hover ? 2.2 : 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: z.risk.color.withValues(alpha: _hover ? 0.5 : 0.25),
                    blurRadius: _hover ? 10 : 6,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                z.displayName,
                style: TextStyle(
                  color: z.risk.color,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.04 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: z.risk.color.withValues(alpha: _hover ? 1 : 0.85),
                      width: _hover ? 2 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: z.risk.color.withValues(alpha: _hover ? 0.45 : 0.2),
                        blurRadius: _hover ? 14 : 8,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        z.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      if (z.fullName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          z.fullName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        z.statusLabel,
                        style: TextStyle(
                          color: z.risk.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(width: 2, height: 8, color: z.risk.color),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: z.risk.color, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapViewModeMenu extends StatelessWidget {
  const _MapViewModeMenu({
    required this.mode,
    required this.onChanged,
  });

  final MapMonitoringViewMode mode;
  final ValueChanged<MapMonitoringViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 168),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _modeTile(
                label: 'Map Viewing',
                icon: Icons.map_outlined,
                selected: mode == MapMonitoringViewMode.mapViewing,
                onTap: () => onChanged(MapMonitoringViewMode.mapViewing),
              ),
              _modeTile(
                label: 'Heat Map',
                icon: Icons.blur_on_rounded,
                selected: mode == MapMonitoringViewMode.heatMap,
                onTap: () => onChanged(MapMonitoringViewMode.heatMap),
              ),
              _modeTile(
                label: 'Density Layers',
                icon: Icons.layers_rounded,
                selected: mode == MapMonitoringViewMode.densityLayers,
                onTap: () => onChanged(MapMonitoringViewMode.densityLayers),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeTile({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AdminColors.statBlue.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? AdminColors.statBlue : AdminColors.headerTitle,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: selected ? AdminColors.statBlue : AdminColors.headerTitle,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_rounded, size: 18, color: AdminColors.statBlue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScaleApproxBadge extends StatelessWidget {
  const _ScaleApproxBadge({required this.zoom});

  final double zoom;

  @override
  Widget build(BuildContext context) {
    final meters = (400000 / math.pow(2, zoom)).clamp(50, 500).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 4,
            decoration: BoxDecoration(
              color: AdminColors.headerTitle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '≈ $meters m',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AdminColors.headerTitle,
            ),
          ),
        ],
      ),
    );
  }
}
