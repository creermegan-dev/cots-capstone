import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'profile_page.dart';
import 'records_page.dart';
import 'user_bottom_nav.dart';
import 'zone_details_page.dart';

// ─── Global colors ─────────────────────────────────────────────────────────
const Color kNavy = Color(0xFF0D1B2A);
const Color kDarkCard = Color(0xFF132337);
const Color kTeal = Color(0xFF00BFA5);
const Color kCyan = Color(0xFF00E5FF);
const Color kGreen = Color(0xFF1B4332);
const Color kHigh = Color(0xFFE53935);
const Color kModerate = Color(0xFFFFA726);
const Color kLow = Color(0xFF43A047);
const Color kGray = Color(0xFFF4F6F9);

// ─── Data models ───────────────────────────────────────────────────────────
enum OutbreakLevel { high, moderate, low }

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

class StatusHistoryItem {
  const StatusHistoryItem({
    required this.date,
    required this.time,
    required this.statusLabel,
    required this.detail,
    required this.isCurrent,
    this.level,
  });

  final String date;
  final String time;
  final String statusLabel;
  final String detail;
  final bool isCurrent;
  final OutbreakLevel? level;
}

class CotsZone {
  const CotsZone({
    required this.id,
    required this.label,
    required this.name,
    required this.position,
    required this.level,
    required this.density,
    required this.status,
    required this.totalScans,
    required this.avgDensity,
    required this.lastScan,
    required this.cotsDetected,
    required this.location,
    required this.radius,
    required this.reason,
    required this.dateCreated,
    required this.statusHistory,
  });

  final String id;
  final String label;
  final String name;
  final LatLng position;
  final OutbreakLevel level;
  final double density;
  final String status;
  final int totalScans;
  final double avgDensity;
  final String lastScan;
  final int cotsDetected;
  final String location;
  final String radius;
  final String reason;
  final String dateCreated;
  final List<StatusHistoryItem> statusHistory;
}

/// Sample zones for the map and detail flows.
const List<CotsZone> kSampleZones = [
  CotsZone(
    id: 'ZD-2024-0007',
    label: 'Zone A',
    name: 'Panabo Reef',
    position: LatLng(7.30, 125.68),
    level: OutbreakLevel.high,
    density: 21.8,
    status: 'Active',
    totalScans: 8,
    avgDensity: 4.2,
    lastScan: 'May 18, 2024 8:30 AM',
    cotsDetected: 125,
    location: '7.1254° N, 125.6748° E',
    radius: '100 m',
    reason: 'No existing zone found within the defined radius.',
    dateCreated: 'May 18, 2024 9:41 AM',
    statusHistory: [
      StatusHistoryItem(
        date: 'May 18, 2024',
        time: '8:30 AM',
        statusLabel: 'Active',
        detail: '(25 COTS detected)',
        isCurrent: true,
        level: OutbreakLevel.high,
      ),
      StatusHistoryItem(
        date: 'May 17, 2024',
        time: '10:20 AM',
        statusLabel: 'Active',
        detail: '(15 COTS detected)',
        isCurrent: false,
        level: OutbreakLevel.high,
      ),
      StatusHistoryItem(
        date: 'May 16, 2024',
        time: '9:05 AM',
        statusLabel: 'Scheduled',
        detail: '',
        isCurrent: false,
        level: OutbreakLevel.moderate,
      ),
      StatusHistoryItem(
        date: 'May 15, 2024',
        time: '4:30 PM',
        statusLabel: 'Cleared',
        detail: '(0 COTS detected)',
        isCurrent: false,
        level: OutbreakLevel.low,
      ),
    ],
  ),
  CotsZone(
    id: 'ZD-2024-0008',
    label: 'Zone B',
    name: 'Samal Reef',
    position: LatLng(7.10, 125.75),
    level: OutbreakLevel.moderate,
    density: 8.6,
    status: 'Scheduled',
    totalScans: 5,
    avgDensity: 7.8,
    lastScan: 'May 17, 2024 2:00 PM',
    cotsDetected: 43,
    location: '7.1000° N, 125.7500° E',
    radius: '80 m',
    reason: 'Routine monitoring zone.',
    dateCreated: 'May 10, 2024 10:00 AM',
    statusHistory: [
      StatusHistoryItem(
        date: 'May 17, 2024',
        time: '2:00 PM',
        statusLabel: 'Scheduled',
        detail: '',
        isCurrent: true,
        level: OutbreakLevel.moderate,
      ),
    ],
  ),
  CotsZone(
    id: 'ZD-2024-0009',
    label: 'Zone C',
    name: 'Island Garden',
    position: LatLng(6.92, 125.62),
    level: OutbreakLevel.low,
    density: 2.1,
    status: 'Cleared',
    totalScans: 3,
    avgDensity: 1.5,
    lastScan: 'May 14, 2024 11:00 AM',
    cotsDetected: 6,
    location: '6.9200° N, 125.6200° E',
    radius: '60 m',
    reason: 'Low density zone, cleared after removal.',
    dateCreated: 'May 5, 2024 8:00 AM',
    statusHistory: [
      StatusHistoryItem(
        date: 'May 14, 2024',
        time: '11:00 AM',
        statusLabel: 'Cleared',
        detail: '(0 COTS detected)',
        isCurrent: true,
        level: OutbreakLevel.low,
      ),
    ],
  ),
  CotsZone(
    id: 'ZD-2024-0010',
    label: 'Zone D',
    name: 'Talikud Reef',
    position: LatLng(6.74, 125.64),
    level: OutbreakLevel.high,
    density: 18.4,
    status: 'Active',
    totalScans: 6,
    avgDensity: 15.0,
    lastScan: 'May 18, 2024 7:00 AM',
    cotsDetected: 98,
    location: '6.7400° N, 125.6400° E',
    radius: '100 m',
    reason: 'High concentration detected.',
    dateCreated: 'May 12, 2024 9:00 AM',
    statusHistory: [
      StatusHistoryItem(
        date: 'May 18, 2024',
        time: '7:00 AM',
        statusLabel: 'Active',
        detail: '(35 COTS detected)',
        isCurrent: true,
        level: OutbreakLevel.high,
      ),
    ],
  ),
];

Color outbreakColor(OutbreakLevel level) {
  switch (level) {
    case OutbreakLevel.high:
      return kHigh;
    case OutbreakLevel.moderate:
      return kModerate;
    case OutbreakLevel.low:
      return kLow;
  }
}

String outbreakLabel(OutbreakLevel level) {
  switch (level) {
    case OutbreakLevel.high:
      return 'High';
    case OutbreakLevel.moderate:
      return 'Moderate';
    case OutbreakLevel.low:
      return 'Low';
  }
}

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
  /// Set after a successful My Location fix; shown as a red dot on the map.
  LatLng? _userLocation;

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
        return 'Tap on a zone to view details.';
      case MapViewMode.heatmap:
        return 'Heatmap shows COTS density intensity.';
      case MapViewMode.density:
        return 'Showing density values (COTS/ha).';
    }
  }

  List<CircleMarker> _buildHeatmapCircles() {
    const radii = <double>[60000, 30000, 12000];
    const opacities = <double>[0.12, 0.28, 0.55];
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
            radius: 5500,
            useRadiusInMeter: true,
            color: outbreakColor(zone.level).withValues(alpha: 0.15),
            borderStrokeWidth: 2,
            borderColor: outbreakColor(zone.level),
          ),
        )
        .toList();
  }

  List<Widget> _mapLayers() {
    final layers = <Widget>[
      TileLayer(
        key: ValueKey(_basemap),
        urlTemplate: _basemap == BasemapKind.standard
            ? _osmTileUrl
            : _satelliteTileUrl,
        userAgentPackageName: 'com.example.cots_monitor',
      ),
    ];

    if (_viewMode == MapViewMode.heatmap) {
      layers.add(CircleLayer(circles: _buildHeatmapCircles()));
    } else if (_viewMode == MapViewMode.density) {
      layers.add(CircleLayer(circles: _buildDensityCircles()));
    }

    final markers = kSampleZones.map((zone) => _zoneMarker(zone)).toList();
    if (_userLocation != null) {
      markers.add(_myLocationDotMarker(_userLocation!));
    }
    layers.add(MarkerLayer(markers: markers));

    return layers;
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

  Marker _zoneMarker(CotsZone zone) {
    final c = outbreakColor(zone.level);
    final statusText = _viewMode == MapViewMode.density
        ? '${zone.density.toStringAsFixed(1)} COTS/ha'
        : '(${outbreakLabel(zone.level)})';

    return Marker(
      point: zone.position,
      width: 132,
      height: 108,
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (context) => ZoneDetailsPage(zone: zone),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: kNavy.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c, width: 1.2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    zone.name,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: c,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 2, height: 6, color: c),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
          ],
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
      extendBody: true,
      appBar: AppBar(
        backgroundColor: kNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {},
        ),
        centerTitle: true,
        title: const Text(
          'COTS Map',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _basemap == BasemapKind.standard
                ? 'Satellite basemap'
                : 'Standard map basemap',
            icon: Icon(
              _basemap == BasemapKind.standard
                  ? Icons.satellite_alt
                  : Icons.map_outlined,
              color: Colors.white,
            ),
            onPressed: _toggleBasemap,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButton: userShellScanFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: UserBottomNavBar(
        active: UserNavDestination.map,
        mapPageBuilder: () => const CotsMapPage(),
        recordsPageBuilder: () => const RecordsPage(),
        profilePageBuilder: () => const ProfilePage(),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(7.05, 125.67),
                initialZoom: 9.5,
                interactionOptions: InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: _mapLayers(),
            ),
          ),
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
        ],
      ),
    );
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
