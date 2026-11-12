import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/supabase_config.dart';
import '../../core/user_shell_theme.dart';
import '../../models/davao_gulf_geography.dart';
import '../../models/monitoring_analytics.dart';
import '../../models/scan_record_model.dart';
import '../../models/submission_group.dart';
import '../../providers/auth_provider.dart';
import '../../services/scan_record_repository.dart';
import '../../services/site_levels_service.dart';
import '../../services/site_partner_service.dart';
import 'profile_page.dart';
import 'records_page.dart';
import 'user_bottom_nav.dart';
import 'user_record_details_page.dart';
import 'user_submission_details_page.dart';

export '../../core/user_shell_theme.dart';
export '../../models/cots_zone.dart';

enum MapViewMode { zones, heatmap, density }

/// Underlying map tiles: streets (OSM) vs aerial (Esri World Imagery).
enum BasemapKind {
  standard,
  satellite,
}

const String _osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Esri uses `{z}/{y}/{x}` tile order (same grid as OSM; flutter_map substitutes correctly).
const String _satelliteTileUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

// ─── Map page ──────────────────────────────────────────────────────────────
/// Vertical space reserved for the bottom legend card so zoom controls sit above it.
const double _kLegendCardApproxHeight = 172;
const double _kZoomAboveLegendGap = 10;

/// Stage 13: one record on the map. Red shows its confirmed COTS count;
/// orange means COTS are still waiting for the Expert.
Marker recordDotMarker(ScanRecordModel record, {VoidCallback? onTap}) {
  final submissionId = record.toAdminTableRow(1).submissionId;
  final tally = record.cotsTally;
  final waiting = tally.waiting > 0;
  final color = waiting ? const Color(0xFFF59E0B) : const Color(0xFFDC2626);
  final label = waiting ? '${tally.waiting}' : '${tally.confirmed}';
  return Marker(
    point: LatLng(record.latitude!, record.longitude!),
    width: 30,
    height: 30,
    alignment: Alignment.center,
    child: GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message:
            '${submissionId.isEmpty ? '' : '$submissionId · '}${record.displayRecordId}\n${record.zone}: ${tally.confirmed} confirmed COTS'
            '${waiting ? ' · ${tally.waiting} waiting' : ''}',
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), blurRadius: 4),
            ],
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    ),
  );
}

/// Records that can be drawn: one per photo record, with a valid location.
List<ScanRecordModel> mappableRecords(List<ScanRecordModel> records) => [
      for (final r in MonitoringAnalytics.fromRecords(records).captures)
        if (r.latitude != null &&
            r.longitude != null &&
            r.latitude!.isFinite &&
            r.longitude!.isFinite &&
            r.latitude!.abs() <= 90 &&
            r.longitude!.abs() <= 180)
          r,
    ];

class CotsMapPage extends StatefulWidget {
  const CotsMapPage({
    super.key,
    this.embedded = false,
    this.diverStyle = false,
    this.recordMarkers = const [],
    this.initialCenter = DavaoGulfGeography.sitesCenter,
    this.initialZoom = DavaoGulfGeography.sitesZoom,
    this.showMyLocation = true,
    this.enableSiteZoom = true,
    this.siteLevels,
    this.ownRecords,
    this.mySites,
    this.records,
    this.onOpenRecord,
  });

  /// Reuses the site map inside admin chrome without diver navigation.
  final bool embedded;

  /// Matches Diver controls while retaining the staff data and navigation.
  final bool diverStyle;
  final List<Marker> recordMarkers;
  final LatLng initialCenter;
  final double initialZoom;
  final bool showMyLocation;

  /// Disabled by the read-only photo overview to preserve its camera behavior.
  final bool enableSiteZoom;

  /// Stage 13 data sources (tests replace them). When null, the Supabase
  /// version loads them; the Firebase rollback shows the sites without levels.
  /// Each site's level for a month (null = each site's latest month).
  final Future<List<SiteLevel>> Function(DateTime? month)? siteLevels;

  /// Embedded (Admin/Expert) maps: all records, filtered by the month picker
  /// like the Diver's own records.
  final List<ScanRecordModel>? records;
  final void Function(ScanRecordModel record)? onOpenRecord;

  /// The signed-in Diver's own records (dots). The admin map passes its
  /// dots through [recordMarkers] instead.
  final Stream<List<ScanRecordModel>>? ownRecords;

  /// Codes of the sites where the signed-in Diver is a main Diver.
  final Future<Set<String>> Function()? mySites;

  @override
  State<CotsMapPage> createState() => _CotsMapPageState();
}

/// Map page (Stages 9 and 13): the dive sites in Samal coloured by their
/// latest Expert-confirmed level (grey = no data yet), the Diver's own sites
/// drawn stronger, and one dot per record.
class _CotsMapPageState extends State<CotsMapPage> {
  final MapController _mapController = MapController();
  MapViewMode _viewMode = MapViewMode.zones;
  BasemapKind _basemap = BasemapKind.standard;
  bool _showInfoBanner = true;

  /// Set after a successful My Location fix; shown as a blue dot on the map.
  LatLng? _userLocation;

  Map<String, SiteLevel> _levels = const {};

  /// The month shown (null = "Latest": each site's latest month with records).
  DateTime? _month;
  Future<List<SiteLevel>> Function(DateTime? month)? _levelsSource;
  Set<String> _mySites = const {};
  List<ScanRecordModel> _records = const [];
  StreamSubscription<List<ScanRecordModel>>? _recordsSub;
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    _loadMapData();
  }

  @override
  void dispose() {
    _recordsSub?.cancel();
    super.dispose();
  }

  String? get _signedInUid {
    try {
      return context.read<AuthProvider>().userModel?.uid;
    } catch (_) {
      return null; // No sign-in around this map (tests, previews).
    }
  }

  Future<void> _loadMapData() async {
    final supabase = SupabaseConfig.isConfigured;
    final Future<List<SiteLevel>> Function(DateTime? month)? levelsSource =
        widget.siteLevels ??
            (supabase
                ? (DateTime? month) => const SiteLevelsApi().monthLevels(month)
                : null);
    _levelsSource = levelsSource;
    final uid = widget.embedded ? null : _signedInUid;
    final recordsStream = widget.ownRecords ??
        (!widget.embedded && uid != null
            ? ScanRecordRepository.watchForUser(uid)
            : null);
    final mySitesSource = widget.mySites ??
        (!widget.embedded && uid != null && supabase
            ? () async => {
                  for (final t in await const SitePartnerApi().teams())
                    if (t.mainDiverUid == uid || t.partnerUid == uid)
                      t.areaCode,
                }
            : null);
    _recordsSub = recordsStream?.listen((records) {
      if (mounted) setState(() => _records = mappableRecords(records));
    }, onError: (_) {});
    await _loadLevels();
    if (mySitesSource != null) {
      try {
        final mine = await mySitesSource();
        if (mounted) setState(() => _mySites = mine);
      } catch (_) {}
    }
  }

  Future<void> _loadLevels() async {
    final source = _levelsSource;
    if (source == null) return;
    final month = _month;
    try {
      final levels = await source(month);
      if (mounted && month == _month) {
        setState(() => _levels = {for (final l in levels) l.areaCode: l});
      }
    } catch (_) {
      // The sites still show, in grey ("No records").
    }
  }

  /// The records drawn as dots and in the heatmap: those of the month shown
  /// (for "Latest", each site's latest month).
  List<ScanRecordModel> get _visibleRecords {
    final all =
        widget.records != null ? mappableRecords(widget.records!) : _records;
    return [
      for (final r in all)
        if (_recordInView(r)) r,
    ];
  }

  bool _recordInView(ScanRecordModel r) {
    final when = r.dateTaken ?? r.submittedAt;
    if (when == null) return _month == null;
    final month = MonthlySiteLevel.monthOf(when);
    if (_month != null) return month == _month;
    final site = DavaoGulfGeography.partAt(r.latitude!, r.longitude!)?.areaCode;
    final shown = site == null ? null : _levels[site]?.month;
    // Without a level yet (loading, or the Firebase rollback) show every dot.
    return shown == null || shown == month;
  }

  void _setMonth(DateTime? month) {
    setState(() {
      _month = month;
      _levels = const {};
    });
    _loadLevels();
  }

  String get _monthPillLabel => _month == null
      ? 'Month: Latest'
      : 'Month: ${MonthlySiteLevel.monthLabel(_month!)}';

  void _openMonthPicker() {
    final now = MonthlySiteLevel.monthOf(DateTime.now());
    final months = [
      for (var i = 0; i < 12; i++) DateTime(now.year, now.month - i),
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                  title: Text('Show month',
                      style: TextStyle(fontWeight: FontWeight.w600))),
              RadioListTile<DateTime?>(
                value: null,
                groupValue: _month,
                title: const Text('Latest'),
                subtitle: const Text("Each site's latest month with records"),
                onChanged: (_) {
                  Navigator.pop(ctx);
                  _setMonth(null);
                },
              ),
              for (final m in months)
                RadioListTile<DateTime?>(
                  value: m,
                  groupValue: _month,
                  title: Text(DateFormat('MMMM yyyy').format(m)),
                  onChanged: (_) {
                    Navigator.pop(ctx);
                    _setMonth(m);
                  },
                ),
            ],
          ),
        ),
      ),
    );
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
        return 'Map View: Sites';
      case MapViewMode.heatmap:
        return 'Map View: Heatmap';
      case MapViewMode.density:
        return 'Map View: Density Layer';
    }
  }

  String get _infoBannerText {
    switch (_viewMode) {
      case MapViewMode.zones:
        return "Sites are coloured by the month's confirmed COTS "
            '(0–15 Low, 16–100 Moderate, over 100 High). '
            'Dots are records: red = confirmed COTS, orange = waiting.';
      case MapViewMode.heatmap:
        return 'Heatmap of the records: brighter where more COTS were recorded.';
      case MapViewMode.density:
        return "Each site's level: confirmed COTS recorded there in the month shown.";
    }
  }

  static const _noDataColor = Color(0xFF9CA3AF);

  static Color levelColor(String? level) => switch (level) {
        'Low' => kLow,
        'Moderate' => kModerate,
        'High' => kHigh,
        _ => _noDataColor,
      };

  /// Every site on the map, in order (Site 1, Site 2, Site 3).
  List<GulfMonitoringArea> get _sites => [
        for (final zone in DavaoGulfGeography.municipalities) ...zone.areas,
      ];

  /// Heatmap from real records: soft circles, stronger with more COTS.
  List<CircleMarker> _buildHeatmapCircles() {
    final out = <CircleMarker>[];
    for (final r in _visibleRecords) {
      final count = r.cotsTally.confirmed + r.cotsTally.waiting;
      if (count <= 0) continue;
      final strength = (count / 10).clamp(0.15, 1.0);
      final color = count >= 10
          ? kHigh
          : count >= 4
              ? kModerate
              : kLow;
      for (final (radius, alpha) in const [
        (260.0, 0.12),
        (140.0, 0.22),
        (60.0, 0.40)
      ]) {
        out.add(CircleMarker(
          point: LatLng(r.latitude!, r.longitude!),
          radius: radius,
          useRadiusInMeter: true,
          color: color.withValues(alpha: alpha * strength + 0.04),
          borderStrokeWidth: 0,
          borderColor: Colors.transparent,
        ));
      }
    }
    return out;
  }

  /// The sites, coloured by level; the signed-in Diver's own sites stronger.
  List<Polygon> _sitePolygons({bool faint = false}) {
    final out = <Polygon>[];
    for (final site in _sites) {
      final color = levelColor(_levels[site.code]?.level);
      final mine = _mySites.contains(site.code);
      for (final ring in site.rings) {
        out.add(Polygon(
          points: ring,
          color: color.withValues(alpha: faint ? 0.10 : 0.30),
          borderColor:
              mine ? kNavy : color.withValues(alpha: faint ? 0.5 : 0.95),
          borderStrokeWidth: mine ? 3.5 : (faint ? 1 : 1.8),
        ));
      }
    }
    return out;
  }

  String _levelLine(SiteLevel? level) {
    if (level?.level == null) return 'No records';
    final month = level!.month;
    return '${level.level} · ${level.confirmedCots} COTS'
        '${month == null ? '' : ' · ${MonthlySiteLevel.monthLabel(month)}'}';
  }

  /// A badge on each site: its name and level (and "Your site").
  List<Marker> _siteLabelMarkers() {
    final out = <Marker>[];
    for (final site in _sites) {
      if (site.parts.isEmpty) continue;
      final part = site.parts.first;
      final level = _levels[site.code];
      final color = levelColor(level?.level);
      final mine = _mySites.contains(site.code);
      out.add(Marker(
        point: part.centroid,
        width: 170,
        height:
            (mine ? 50 : 36) * MediaQuery.textScalerOf(context).scale(1) + 6,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () => _selectSite(site),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Color.lerp(Colors.white, color, 0.18)!,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: mine ? kNavy : color.withValues(alpha: 0.9),
                  width: mine ? 2 : 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(site.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kNavy)),
                Text(_levelLine(level),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: kNavy)),
                if (mine)
                  const Text('Your site',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: kNavy)),
              ],
            ),
          ),
        ),
      ));
    }
    return out;
  }

  void _selectSite(GulfMonitoringArea area) {
    final points = area.rings.expand((ring) => ring).toList();
    if (widget.enableSiteZoom && points.length > 1) {
      final size = _mapController.camera.nonRotatedSize;
      final horizontal = math.min(48.0, size.x * 0.12);
      final bottom = _kLegendCardApproxHeight +
          96 +
          (widget.embedded ? 0 : MediaQuery.of(context).padding.bottom + 80);
      _mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: EdgeInsets.fromLTRB(horizontal, math.min(160.0, size.y * 0.25),
            horizontal, math.min(bottom, size.y * 0.4)),
        maxZoom: 17,
      ));
    }
    if (area.parts.isNotEmpty) _showSiteInfo(area.parts.first);
  }

  void _onMapTap(TapPosition _, LatLng point) {
    final part = DavaoGulfGeography.partAt(point.latitude, point.longitude,
        allowanceMeters: 0);
    if (part == null) return;
    for (final site in _sites) {
      if (site.code == part.areaCode) {
        _selectSite(site);
        return;
      }
    }
  }

  void _showSiteInfo(GulfCoastalBarangay site) {
    final level = _levels[site.id];
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(
      content: Text(
        '${site.displayName} · Barangay ${site.name}, Samal\n'
        'Size: ${site.reefHectares.toStringAsFixed(0)} ha · '
        'Level: ${_levelLine(level)}\n'
        'Records: ${level?.records ?? 0} · Confirmed COTS: ${level?.confirmedCots ?? 0}'
        '${(level?.waitingCots ?? 0) > 0 ? ' · Waiting: ${level!.waitingCots}' : ''}',
      ),
    ));
  }

  void _openRecord(ScanRecordModel record) {
    final groups = SubmissionGroup.fromRecords(_records);
    for (final group in groups) {
      if (group.hasBatch &&
          group.records.any((photo) =>
              photo.id == record.id &&
              photo.uid == record.uid &&
              photo.recordCollection == record.recordCollection)) {
        Navigator.of(context).push<void>(MaterialPageRoute(
            builder: (_) => UserSubmissionDetailsPage(initialGroup: group)));
        return;
      }
    }
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => UserRecordDetailsPage(record: record),
    ));
  }

  List<Widget> _mapLayers() {
    final useSatellite = _basemap == BasemapKind.satellite;
    final layers = <Widget>[
      TileLayer(
        key: ValueKey(useSatellite),
        urlTemplate: useSatellite ? _satelliteTileUrl : _osmTileUrl,
        userAgentPackageName: 'com.example.cots_monitor',
      ),
    ];

    layers.add(PolygonLayer(
        polygons: _sitePolygons(faint: _viewMode == MapViewMode.heatmap)));
    if (_viewMode == MapViewMode.heatmap) {
      layers.add(CircleLayer(circles: _buildHeatmapCircles()));
    }

    final markers = <Marker>[];
    markers.addAll(_siteLabelMarkers());
    if (_viewMode != MapViewMode.heatmap) {
      for (final r in _visibleRecords) {
        markers.add(recordDotMarker(r,
            onTap: () => widget.onOpenRecord != null
                ? widget.onOpenRecord!(r)
                : _openRecord(r)));
      }
    }
    if (_userLocation != null) {
      markers.add(_myLocationDotMarker(_userLocation!));
    }
    markers.addAll(widget.recordMarkers);
    layers.add(MarkerLayer(markers: markers));
    if (widget.embedded) {
      layers.add(RichAttributionWidget(attributions: [
        TextSourceAttribution(
            useSatellite ? 'Esri World Imagery' : 'OpenStreetMap contributors'),
      ]));
    }

    return layers;
  }

  /// Blue dot at the GPS position after My Location is used (red/orange are records).
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
          color: const Color(0xFF2563EB),
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
                label: 'Sites',
              ),
              if (!widget.embedded || widget.diverStyle) ...[
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
    if (widget.embedded) {
      return _mapContent(
          zoomBottom: widget.diverStyle
              ? _kLegendCardApproxHeight + _kZoomAboveLegendGap
              : 16,
          bottomOverlay: 0);
    }
    final bottomOverlay = MediaQuery.of(context).padding.bottom + 80;
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
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MAP PAGE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kGreen,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Monitor the 3 dive sites in Samal.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _mapContent(
                  zoomBottom: zoomBottom, bottomOverlay: bottomOverlay),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapContent({
    required double zoomBottom,
    required double bottomOverlay,
  }) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.initialCenter,
                initialZoom: widget.initialZoom,
                onTap: widget.enableSiteZoom ? _onMapTap : null,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
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
    );
  }

  Widget _mapSelector(
      {required Key key,
      required IconData icon,
      required String label,
      required String tooltip,
      required VoidCallback onTap}) {
    final compact = !widget.embedded || widget.diverStyle;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
            key: key,
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 12, vertical: compact ? 8 : 10),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 8,
                        offset: Offset(0, 2))
                  ]),
              child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: compact ? 28 : 20),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, color: kNavy, size: compact ? 18 : 20),
                    SizedBox(width: compact ? 4 : 8),
                    Flexible(
                        child: Text(label,
                            style: TextStyle(
                                color: kNavy,
                                fontWeight: FontWeight.w600,
                                fontSize: compact ? 11 : 12),
                            overflow: TextOverflow.ellipsis)),
                    Icon(Icons.keyboard_arrow_down,
                        color: kNavy, size: compact ? 16 : 20),
                  ])),
            )),
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
            LayoutBuilder(builder: (context, constraints) {
              final compact = !widget.embedded || widget.diverStyle;
              final shortLabels = compact && constraints.maxWidth < 300;
              final viewControl = _mapSelector(
                key: const ValueKey('map-view-picker'),
                icon: Icons.layers_outlined,
                label: shortLabels
                    ? _modePillLabel.replaceFirst('Map View: ', '')
                    : _modePillLabel,
                tooltip: _modePillLabel,
                onTap: _openLayerPicker,
              );
              final monthControl = _mapSelector(
                key: const ValueKey('map-month-picker'),
                icon: Icons.calendar_month_outlined,
                label: shortLabels
                    ? _monthPillLabel.replaceFirst('Month: ', '')
                    : _monthPillLabel,
                tooltip: _monthPillLabel,
                onTap: _openMonthPicker,
              );
              if (widget.embedded && !widget.diverStyle) {
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      viewControl,
                      const SizedBox(height: 8),
                      monthControl
                    ]);
              }
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: viewControl),
                const SizedBox(width: 6),
                Flexible(child: monthControl),
              ]);
            }),
            if (widget.embedded && !widget.diverStyle && _showInfoBanner) ...[
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
                    const Icon(Icons.info_outline, color: kNavy, size: 18),
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
                      onPressed: () => setState(() => _showInfoBanner = false),
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
      if (!widget.embedded || widget.diverStyle)
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
          if (widget.showMyLocation)
            _mapToolTile(
              icon: Icons.my_location_outlined,
              label: 'My\nLocation',
              onTap: _goToMyLocation,
            ),
          if (widget.showMyLocation)
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
            'SITE LEVEL (confirmed COTS per month)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: kNavy,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 10,
            runSpacing: 4,
            children: [
              _legendDotPair('Low ≤15', kLow),
              _legendDotPair('Moderate 16–100', kModerate),
              _legendDotPair('High >100', kHigh),
              _legendDotPair('No records', _noDataColor),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 10,
            children: [
              _legendDotPair('Record: confirmed COTS', const Color(0xFFDC2626)),
              _legendDotPair('Waiting for Expert', const Color(0xFFF59E0B)),
            ],
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
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: kNavy,
            ),
          ),
        ),
      ],
    );
  }
}
