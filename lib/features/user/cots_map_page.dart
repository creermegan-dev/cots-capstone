import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/user_shell_theme.dart';
import '../../models/cots_marine_sector_palette.dart';
import '../../models/cots_zone.dart';
import '../../models/davao_gulf_geography.dart';
import '../../widgets/marine_sector_map_label.dart';
import 'profile_page.dart';
import 'records_page.dart';
import 'user_bottom_nav.dart';
import 'zone_details_page.dart';

export '../../core/user_shell_theme.dart';
export '../../models/cots_zone.dart';

enum MapViewMode { zones, heatmap, density }

/// Underlying map tiles: streets (OSM) vs aerial (Esri World Imagery).
enum BasemapKind {
  standard,
  satellite,
}

const String _osmTileUrl =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
/// Esri uses `{z}/{y}/{x}` tile order (same grid as OSM; flutter_map substitutes correctly).
const String _satelliteTileUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

// ─── Map page ──────────────────────────────────────────────────────────────
/// Vertical space reserved for the bottom legend card so zoom controls sit above it.
const double _kLegendCardApproxHeight = 138;
const double _kZoomAboveLegendGap = 10;

class CotsMapPage extends StatefulWidget {
  const CotsMapPage({super.key});

  @override
  State<CotsMapPage> createState() => _CotsMapPageState();
}

class _CotsMapPageState extends State<CotsMapPage> {
  final MapController _mapController = MapController();
  MapViewMode _viewMode = MapViewMode.zones;
  BasemapKind _basemap = BasemapKind.standard;
  bool _showInfoBanner = true;
  double _mapZoom = 8.3;
  String? _selectedZoneCode;
  /// Set after a successful My Location fix; shown as a red dot on the map.
  LatLng? _userLocation;

  static const _overviewZoomCutoff = 9.8;
  static const _gulfOverview = LatLng(7.05, 125.62);

  bool get _isDrilledIn => _selectedZoneCode != null;

  bool get _marineSectorView =>
      _isDrilledIn && (_selectedMunicipality?.marineSectorLayout ?? false);

  GulfCoastalMunicipality? get _selectedMunicipality {
    if (_selectedZoneCode == null) return null;
    return DavaoGulfGeography.municipalityByZoneCode(_selectedZoneCode!);
  }

  void _toggleBasemap() {
    setState(() {
      _basemap = _basemap == BasemapKind.standard
          ? BasemapKind.satellite
          : BasemapKind.standard;
    });
  }

  String get _modePillLabel {
    switch (_viewMode) {
      case MapViewMode.zones:
        return 'Map View: Zones';
      case MapViewMode.heatmap:
        return 'Map View: Heatmap';
      case MapViewMode.density:
        return 'Map View: Density Layer';
    }
  }

  String get _infoBannerText {
    switch (_viewMode) {
      case MapViewMode.zones:
        if (_isDrilledIn) {
          final m = _selectedMunicipality;
          return '${m?.zoneLabel ?? 'Zone'} — tap a site code for details.';
        }
        return 'Davao Gulf zones A–Q — tap a zone to view barangay sites.';
      case MapViewMode.heatmap:
        return 'Heatmap shows COTS density intensity by barangay.';
      case MapViewMode.density:
        return 'Density values (COTS/ha) by coastal barangay.';
    }
  }

  CotsZone? _zoneForBarangayId(String id) {
    for (final zone in kSampleZones) {
      if (zone.id == id) return zone;
    }
    return null;
  }

  List<CircleMarker> _buildHeatmapCircles() {
    const radii = <double>[4200, 2200, 900];
    const opacities = <double>[0.10, 0.22, 0.42];
    final out = <CircleMarker>[];
    for (final zone in kSampleZones) {
      final c = outbreakColor(zone.level);
      for (var i = 0; i < radii.length; i++) {
        out.add(
          CircleMarker(
            point: zone.position,
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

  List<CircleMarker> _buildDensityCircles() {
    return kSampleZones
        .map(
          (zone) => CircleMarker(
            point: zone.position,
            radius: 2800,
            useRadiusInMeter: true,
            color: outbreakColor(zone.level).withValues(alpha: 0.14),
            borderStrokeWidth: 2,
            borderColor: outbreakColor(zone.level),
          ),
        )
        .toList();
  }

  void _drillIntoZone(GulfCoastalMunicipality municipality) {
    final barangays = municipality.barangays;
    if (barangays.isEmpty) return;

    if (municipality.marineSectorLayout) {
      _mapController.move(
        DavaoGulfGeography.panaboMarineSectorCenter,
        DavaoGulfGeography.panaboMarineSectorZoom,
      );
      setState(() {
        _selectedZoneCode = municipality.zoneCode;
        _mapZoom = DavaoGulfGeography.panaboMarineSectorZoom;
      });
      return;
    }

    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final b in barangays) {
      for (final p in b.polygon) {
        minLat = math.min(minLat, p.latitude);
        maxLat = math.max(maxLat, p.latitude);
        minLng = math.min(minLng, p.longitude);
        maxLng = math.max(maxLng, p.longitude);
      }
    }
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    const drillZoom = 12.8;
    _mapController.move(center, drillZoom);
    setState(() {
      _selectedZoneCode = municipality.zoneCode;
      _mapZoom = drillZoom;
    });
  }

  void _backToZones() {
    _mapController.move(_gulfOverview, 8.3);
    setState(() {
      _selectedZoneCode = null;
      _mapZoom = 8.3;
    });
  }

  List<Polygon> _municipalityPolygons({bool faint = false}) {
    final municipalities = _isDrilledIn
        ? [_selectedMunicipality!]
        : DavaoGulfGeography.municipalities;
    return municipalities.map((m) {
      return Polygon(
        points: m.boundary,
        color: faint
            ? kNavy.withValues(alpha: 0.03)
            : kTeal.withValues(alpha: 0.08),
        borderColor: faint
            ? kNavy.withValues(alpha: 0.35)
            : kNavy.withValues(alpha: 0.75),
        borderStrokeWidth: faint ? 1 : 2,
      );
    }).toList();
  }

  List<Polygon> _barangayPolygons() {
    final barangays = _isDrilledIn
        ? _selectedMunicipality!.barangays
        : const <GulfCoastalBarangay>[];
    return barangays.map((b) {
      if (_marineSectorView) {
        final accent = marineSectorColor(b.siteCode);
        return Polygon(
          points: b.polygon,
          color: accent.withValues(alpha: 0.38),
          borderColor: accent,
          borderStrokeWidth: 1.8,
        );
      }
      final zone = _zoneForBarangayId(b.id);
      final accent = zone != null
          ? outbreakColor(zone.level)
          : kTeal;
      return Polygon(
        points: b.polygon,
        color: accent.withValues(alpha: 0.30),
        borderColor: accent.withValues(alpha: 0.95),
        borderStrokeWidth: 2.2,
      );
    }).toList();
  }

  List<Marker> _marineSectorLabelMarkers() {
    if (!_marineSectorView || _selectedMunicipality == null) return const [];
    return _selectedMunicipality!.barangays
        .map(
          (b) => Marker(
            point: b.centroid,
            width: 72,
            height: 40,
            alignment: Alignment.center,
            child: MarineSectorMapLabel(siteCode: b.siteCode),
          ),
        )
        .toList();
  }

  List<Widget> _mapLayers() {
    final useSatellite = _basemap == BasemapKind.satellite || _marineSectorView;
    final layers = <Widget>[
      TileLayer(
        key: ValueKey(useSatellite),
        urlTemplate: useSatellite
            ? _satelliteTileUrl
            : _osmTileUrl,
        userAgentPackageName: 'com.example.cots_monitor',
      ),
    ];

    if (_viewMode == MapViewMode.heatmap && !_marineSectorView) {
      layers.add(CircleLayer(circles: _buildHeatmapCircles()));
    } else if (_viewMode == MapViewMode.density && !_marineSectorView) {
      layers.add(CircleLayer(circles: _buildDensityCircles()));
    }

    if (_viewMode == MapViewMode.zones) {
      if (_isDrilledIn) {
        if (!_marineSectorView) {
          layers.add(PolygonLayer(polygons: _municipalityPolygons(faint: true)));
        }
        layers.add(PolygonLayer(polygons: _barangayPolygons()));
      } else {
        layers.add(PolygonLayer(polygons: _municipalityPolygons()));
      }
    }

    final markers = <Marker>[];
    if (_viewMode == MapViewMode.zones) {
      if (_marineSectorView) {
        markers.addAll(_marineSectorLabelMarkers());
      } else if (_isDrilledIn) {
        for (final b in _selectedMunicipality!.barangays) {
          final zone = _zoneForBarangayId(b.id);
          if (zone != null) markers.add(_siteMarker(zone));
        }
      } else {
        for (final m in DavaoGulfGeography.municipalities) {
          markers.add(_municipalityMarker(m));
        }
      }
    } else if (!_marineSectorView) {
      for (final zone in kSampleZones) {
        markers.add(_siteMarker(zone, showDensity: _viewMode == MapViewMode.density));
      }
    }
    if (_userLocation != null) {
      markers.add(_myLocationDotMarker(_userLocation!));
    }
    layers.add(MarkerLayer(markers: markers));

    return layers;
  }

  Marker _municipalityMarker(GulfCoastalMunicipality municipality) {
    return Marker(
      point: municipality.centroid,
      width: 128,
      height: 64,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () => _drillIntoZone(municipality),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kTeal.withValues(alpha: 0.85)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                municipality.zoneLabel,
                style: const TextStyle(
                  color: kTeal,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              Text(
                municipality.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Red dot at GPS position after My Location is used.
  Marker _myLocationDotMarker(LatLng point) {
    return Marker(
      point: point,
      width: 28,
      height: 28,
      alignment: Alignment.center,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x59000000),
              blurRadius: 6,
              spreadRadius: 0,
            ),
          ],
        ),
      ),
    );
  }

  Marker _siteMarker(CotsZone zone, {bool showDensity = false}) {
    final c = outbreakColor(zone.level);

    return Marker(
      point: zone.position,
      width: 48,
      height: 48,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (context) => ZoneDetailsPage(zone: zone),
            ),
          );
        },
        child: Tooltip(
          message: zone.name,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kNavy.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  border: Border.all(color: c, width: 1.6),
                ),
                child: Text(
                  zone.label,
                  style: TextStyle(
                    color: c,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (showDensity)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${zone.density.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: c,
                      fontWeight: FontWeight.w700,
                      fontSize: 8,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openLayerPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: kDarkCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select Map View',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              _layerTile(
                mode: MapViewMode.zones,
                icon: Icons.map_outlined,
                label: 'Zones',
              ),
              const SizedBox(height: 10),
              _layerTile(
                mode: MapViewMode.heatmap,
                icon: Icons.blur_on_outlined,
                label: 'Heatmap',
              ),
              const SizedBox(height: 10),
              _layerTile(
                mode: MapViewMode.density,
                icon: Icons.bubble_chart_outlined,
                label: 'Density Layer',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _layerTile({
    required MapViewMode mode,
    required IconData icon,
    required String label,
  }) {
    final selected = _viewMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _viewMode = mode;
          _showInfoBanner = true;
        });
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? kTeal.withValues(alpha: 0.15) : kDarkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? kTeal : const Color(0xFF1E3A5F),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? kTeal : Colors.white, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: selected ? kTeal : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            if (selected) const Icon(Icons.check, color: kTeal, size: 22),
          ],
        ),
      ),
    );
  }

  void _zoomBy(double delta) {
    final cam = _mapController.camera;
    _mapController.move(cam.center, cam.zoom + delta);
  }

  Future<void> _goToMyLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turn on location services to use My Location.'),
          ),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied.')),
        );
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location is blocked. Enable it in system settings for this app.',
            ),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      final latLng = LatLng(position.latitude, position.longitude);
      final cam = _mapController.camera;
      final zoom = cam.zoom < 12 ? 14.0 : cam.zoom;
      setState(() => _userLocation = latLng);
      _mapController.move(latLng, zoom);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomOverlay =
        MediaQuery.of(context).padding.bottom + 80;
    final zoomBottom =
        bottomOverlay + _kLegendCardApproxHeight + _kZoomAboveLegendGap;

    return Scaffold(
      backgroundColor: kGray,
      extendBody: true,
      floatingActionButton: userShellScanFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: UserBottomNavBar(
        active: UserNavDestination.map,
        mapPageBuilder: () => const CotsMapPage(),
        recordsPageBuilder: () => const RecordsPage(),
        profilePageBuilder: () => const ProfilePage(),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MAP PAGE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: kGreen,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Monitor Davao Gulf coastal cities and barangays.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _basemap == BasemapKind.standard
                        ? 'Satellite basemap'
                        : 'Standard map basemap',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    icon: Icon(
                      _basemap == BasemapKind.standard
                          ? Icons.satellite_alt
                          : Icons.map_outlined,
                      color: kNavy,
                    ),
                    onPressed: _toggleBasemap,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: const LatLng(7.05, 125.62),
                          initialZoom: 8.3,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                          onMapEvent: (event) {
                            final zoom = event.camera.zoom;
                            if ((zoom - _mapZoom).abs() > 0.05) {
                              setState(() {
                                _mapZoom = zoom;
                                if (_isDrilledIn && zoom < _overviewZoomCutoff) {
                                  _selectedZoneCode = null;
                                }
                              });
                            }
                          },
                        ),
                        children: _mapLayers(),
                      ),
                    ),
                  ),
                  ..._mapOverlayChildren(
                    zoomBottom: zoomBottom,
                    bottomOverlay: bottomOverlay,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _mapOverlayChildren({
    required double zoomBottom,
    required double bottomOverlay,
  }) {
    return [
          Positioned(
            top: 12,
            left: 12,
            right: 82,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openLayerPicker,
                    borderRadius: BorderRadius.circular(10),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.layers_outlined,
                              color: kNavy, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _modePillLabel,
                              style: const TextStyle(
                                color: kNavy,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down,
                              color: kNavy, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_isDrilledIn && _viewMode == MapViewMode.zones) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _backToZones,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_rounded, color: kNavy, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'All zones',
                              style: TextStyle(
                                color: kNavy,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (_showInfoBanner) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: kNavy, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _infoBannerText,
                            style: const TextStyle(
                              color: kNavy,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              setState(() => _showInfoBanner = false),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: _mapToolsStrip(),
          ),
          if (_isDrilledIn && _viewMode == MapViewMode.zones)
            Positioned(
              top: 12,
              right: 84,
              child: Material(
                color: Colors.white,
                elevation: 2,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _backToZones,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 18, color: kNavy),
                        SizedBox(width: 4),
                        Text(
                          'Zones',
                          style: TextStyle(
                            color: kNavy,
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
          Positioned(
            bottom: zoomBottom,
            right: 12,
            child: _zoomStrip(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomOverlay,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _legendCard(),
            ),
          ),
    ];
  }

  /// My Location + Basemap (layer mode stays on the top-left pill only).
  Widget _mapToolsStrip() {
    return Container(
      width: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _mapToolTile(
            icon: Icons.my_location_outlined,
            label: 'My\nLocation',
            onTap: _goToMyLocation,
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          _mapToolTile(
            icon: _basemap == BasemapKind.standard
                ? Icons.satellite_alt
                : Icons.map_outlined,
            label: _basemap == BasemapKind.standard ? 'Satellite' : 'Map',
            onTap: _toggleBasemap,
          ),
        ],
      ),
    );
  }

  Widget _mapToolTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: kNavy, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w600,
                  color: kNavy,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _zoomStrip() {
    return Material(
      elevation: 10,
      shadowColor: Colors.black54,
      borderRadius: BorderRadius.circular(10),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black26, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'Zoom in',
              child: InkWell(
                onTap: () => _zoomBy(1),
                child: const SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(Icons.add, color: kNavy, size: 17),
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: Colors.grey.shade300),
            Tooltip(
              message: 'Zoom out',
              child: InkWell(
                onTap: () => _zoomBy(-1),
                child: const SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(Icons.remove, color: kNavy, size: 17),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'COTS DENSITY (COTS/ha)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: kNavy,
            ),
          ),
          const SizedBox(height: 10),
          if (_viewMode == MapViewMode.heatmap) ...[
            Container(
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E88E5),
                    kLow,
                    kModerate,
                    kHigh,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Low',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                Text('Moderate',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                Text('High',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _legendDotPair('Low', kLow),
                _legendDotPair('Moderate', kModerate),
                _legendDotPair('High', kHigh),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '0 – 5          5 – 15          > 15',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: kNavy,
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Tap on a zone to view more details.',
            style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _legendDotPair(String label, Color color) {
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
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: kNavy,
          ),
        ),
      ],
    );
  }
}
