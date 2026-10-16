import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Administrative level for Davao Gulf coastal monitoring areas.
enum GulfAreaLevel { municipality, barangay }

/// One coastal barangay with an approximate nearshore monitoring patch.
class GulfCoastalBarangay {
  const GulfCoastalBarangay({
    required this.id,
    required this.siteCode,
    required this.name,
    required this.municipalityId,
    required this.municipalityName,
    required this.zoneCode,
    required this.province,
    required this.centroid,
    required this.polygon,
    this.beachNote,
  });

  final String id;
  /// Short map label, e.g. `A-01` under Zone A (Panabo).
  final String siteCode;
  final String name;
  final String municipalityId;
  final String municipalityName;
  final String zoneCode;
  final String province;
  final LatLng centroid;
  final List<LatLng> polygon;
  final String? beachNote;

  String get displayLabel => siteCode;
  String get subtitle => '$name · $municipalityName';
  String get zoneLabel => 'Zone $zoneCode';
}

/// City/municipality along Davao Gulf (coastal LGU envelope for map overview).
class GulfCoastalMunicipality {
  const GulfCoastalMunicipality({
    required this.id,
    required this.zoneCode,
    required this.name,
    required this.province,
    required this.kind,
    required this.centroid,
    required this.boundary,
    required this.barangays,
    this.reference,
    this.marineSectorLayout = false,
  });

  final String id;
  /// Letter code shown on the map, e.g. `A` for Panabo City.
  final String zoneCode;
  final String name;
  final String province;
  final String kind;
  final LatLng centroid;
  final List<LatLng> boundary;
  final List<GulfCoastalBarangay> barangays;
  final String? reference;
  /// When true, barangay polygons are contiguous coastal strips (shore → sea).
  final bool marineSectorLayout;

  String get zoneLabel => 'Zone $zoneCode';
  int get barangayCount => barangays.length;
}

/// Result of GPS-based zone lookup.
class GulfZoneAssignment {
  const GulfZoneAssignment({
    required this.municipality,
    required this.barangay,
    required this.zoneLabel,
  });

  final GulfCoastalMunicipality municipality;
  final GulfCoastalBarangay barangay;
  final String zoneLabel;
}

/// Davao Gulf coastal municipalities and beach-facing barangays.
///
/// Sources: UP Mindanao Davao Gulf coastal vulnerability project (17 LGUs);
/// Davao City CRM coastal barangay table; PhilAtlas barangay centroids;
/// Tagum City mangrove/coastal studies (Madaum, Busaon, San Isidro);
/// San Isidro (Davao Oriental) coastal barangay profile; Samal IGAC coastal profile.
abstract final class DavaoGulfGeography {
  static const _distance = Distance();

  static List<GulfCoastalMunicipality>? _cache;

  static List<GulfCoastalMunicipality> get municipalities {
    return _cache ??= _buildMunicipalities();
  }

  static List<GulfCoastalBarangay> get allBarangays => [
        for (final m in municipalities) ...m.barangays,
      ];

  static GulfCoastalMunicipality? municipalityByZoneCode(String zoneCode) {
    for (final m in municipalities) {
      if (m.zoneCode == zoneCode) return m;
    }
    return null;
  }

  static List<LatLng> boundsPointsFor(GulfCoastalMunicipality municipality) {
    return municipality.boundary;
  }

  static GulfZoneAssignment? assign({double? latitude, double? longitude}) {
    if (latitude == null || longitude == null) return null;
    final point = LatLng(latitude, longitude);

    GulfCoastalBarangay? bestBarangay;
    GulfCoastalMunicipality? bestMunicipality;
    var bestMeters = double.infinity;

    for (final municipality in municipalities) {
      for (final barangay in municipality.barangays) {
        if (!_pointInPolygon(point, barangay.polygon)) continue;
        final meters = _distance.as(
          LengthUnit.Meter,
          point,
          barangay.centroid,
        );
        if (meters < bestMeters) {
          bestMeters = meters;
          bestBarangay = barangay;
          bestMunicipality = municipality;
        }
      }
    }

    if (bestBarangay != null && bestMunicipality != null) {
      return GulfZoneAssignment(
        municipality: bestMunicipality,
        barangay: bestBarangay,
        zoneLabel: '${bestBarangay.zoneLabel} · ${bestBarangay.siteCode}',
      );
    }

    GulfCoastalMunicipality? nearestMunicipality;
    bestMeters = double.infinity;
    for (final municipality in municipalities) {
      final meters = _distance.as(
        LengthUnit.Meter,
        point,
        municipality.centroid,
      );
      if (meters < bestMeters) {
        bestMeters = meters;
        nearestMunicipality = municipality;
      }
    }

    if (nearestMunicipality == null || bestMeters > 25000) return null;

    GulfCoastalBarangay? nearestBarangay;
    var barangayMeters = double.infinity;
    for (final barangay in nearestMunicipality.barangays) {
      final meters = _distance.as(
        LengthUnit.Meter,
        point,
        barangay.centroid,
      );
      if (meters < barangayMeters) {
        barangayMeters = meters;
        nearestBarangay = barangay;
      }
    }
    if (nearestBarangay == null || barangayMeters > 12000) return null;

    return GulfZoneAssignment(
      municipality: nearestMunicipality,
      barangay: nearestBarangay,
      zoneLabel: nearestBarangay.name,
    );
  }

  /// Resolves a monitoring area only when the coordinate is inside exactly one
  /// mapped site polygon. Unlike [assign], this never uses a nearest-area fallback.
  static GulfZoneAssignment? assignWithinMonitoringArea({
    double? latitude,
    double? longitude,
  }) {
    if (latitude == null || longitude == null ||
        !latitude.isFinite || !longitude.isFinite ||
        latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return null;
    }
    final point = LatLng(latitude, longitude);
    final matches = <(GulfCoastalMunicipality, GulfCoastalBarangay)>[];

    for (final municipality in municipalities) {
      for (final barangay in municipality.barangays) {
        if (_pointInPolygon(point, barangay.polygon)) {
          matches.add((municipality, barangay));
        }
      }
    }

    if (matches.length != 1) return null;
    final (municipality, barangay) = matches.single;
    return GulfZoneAssignment(
      municipality: municipality,
      barangay: barangay,
      zoneLabel: '${barangay.zoneLabel} · ${barangay.siteCode}',
    );
  }

  static GulfCoastalBarangay? barangayById(String id) {
    for (final b in allBarangays) {
      if (b.id == id) return b;
    }
    return null;
  }

  static GulfCoastalMunicipality? municipalityById(String id) {
    for (final m in municipalities) {
      if (m.id == id) return m;
    }
    return null;
  }

  static List<LatLng> coastalPatch(
    double lat,
    double lng, {
    double latSpan = 0.0055,
    double lngSpan = 0.0075,
  }) {
    return nearshoreSurveyPatch(LatLng(lat, lng));
  }

  /// Contiguous coastal management sector from shoreline to offshore.
  ///
  /// [shoreStart]–[shoreEnd] form the landward edge; the seaward edge is a
  /// parallel offset so adjacent sectors share vertices and borders.
  static List<LatLng> coastalSectorPolygon({
    required LatLng shoreStart,
    required LatLng shoreEnd,
    required double seaBearingDeg,
    required double offshoreMeters,
    double shoreInsetMeters = 14,
  }) {
    return coastalSectorStripPolygon(
      coastPoints: [shoreStart, shoreEnd],
      preferredSeaBearingDeg: seaBearingDeg,
      offshoreMeters: offshoreMeters,
      shoreInsetMeters: shoreInsetMeters,
    );
  }

  /// Marine sector polygon traced along a coast polyline.
  ///
  /// Each coast vertex is nudged seaward using the local shoreline tangent,
  /// producing adjacent sectors with a shared continuous offshore edge.
  static List<LatLng> coastalSectorStripPolygon({
    required List<LatLng> coastPoints,
    required double preferredSeaBearingDeg,
    double offshoreMeters = 900,
    double shoreInsetMeters = 12,
  }) {
    if (coastPoints.length < 2) return const [];

    final landEdge = <LatLng>[];
    final seaEdge = <LatLng>[];

    for (var i = 0; i < coastPoints.length; i++) {
      final tangent = _coastTangentBearing(coastPoints, i);
      final seaBearing = _seaBearingFromTangent(tangent, preferredSeaBearingDeg);
      final land = _offsetMeters(coastPoints[i], seaBearing, shoreInsetMeters);
      landEdge.add(land);
      seaEdge.add(_offsetMeters(land, seaBearing, offshoreMeters));
    }

    return [...landEdge, ...seaEdge.reversed];
  }

  static double _bearingDeg(LatLng from, LatLng to) {
    final phi1 = from.latitude * math.pi / 180;
    final phi2 = to.latitude * math.pi / 180;
    final dLambda = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static double _coastTangentBearing(List<LatLng> points, int index) {
    if (points.length < 2) return 0;
    if (index == 0) return _bearingDeg(points[0], points[1]);
    if (index == points.length - 1) {
      return _bearingDeg(points[index - 1], points[index]);
    }
    return _averageBearing(
      _bearingDeg(points[index - 1], points[index]),
      _bearingDeg(points[index], points[index + 1]),
    );
  }

  static double _averageBearing(double a, double b) {
    final aRad = a * math.pi / 180;
    final bRad = b * math.pi / 180;
    final x = math.cos(aRad) + math.cos(bRad);
    final y = math.sin(aRad) + math.sin(bRad);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static double _seaBearingFromTangent(
    double tangentDeg,
    double preferredSeaBearingDeg,
  ) {
    final optionA = (tangentDeg + 90) % 360;
    final optionB = (tangentDeg - 90) % 360;
    return _bearingCloserTo(optionA, optionB, preferredSeaBearingDeg);
  }

  static double _bearingCloserTo(double a, double b, double target) {
    double angularDiff(double x, double y) {
      var d = (x - y).abs() % 360;
      if (d > 180) d = 360 - d;
      return d;
    }

    return angularDiff(a, target) <= angularDiff(b, target) ? a : b;
  }

  static LatLng _marineSectorLabelPoint(
    List<LatLng> coastPoints, {
    required double preferredSeaBearingDeg,
    double offshoreMeters = 900,
    double shoreInsetMeters = 12,
  }) {
    final mid = coastPoints.length ~/ 2;
    final tangent = _coastTangentBearing(coastPoints, mid);
    final seaBearing = _seaBearingFromTangent(tangent, preferredSeaBearingDeg);
    final land = _offsetMeters(coastPoints[mid], seaBearing, shoreInsetMeters);
    return _offsetMeters(land, seaBearing, offshoreMeters * 0.52);
  }

  /// Builds shared nearshore/sea edges for a full coastline arc.
  /// [shoreInsetMeters] pushes the landward edge into the water so no boundary
  /// line appears on land (Option 2 water-only requirement).
  static ({List<LatLng> land, List<LatLng> sea}) _coastArcEdges(
    List<LatLng> coastline, {
    required double preferredSeaBearingDeg,
    required double offshoreMeters,
    double shoreInsetMeters = 40,
  }) {
    final land = <LatLng>[];
    final sea = <LatLng>[];
    for (var i = 0; i < coastline.length; i++) {
      final tangent = _coastTangentBearing(coastline, i);
      final seaBearing = _seaBearingFromTangent(tangent, preferredSeaBearingDeg);
      final shore = _offsetMeters(coastline[i], seaBearing, shoreInsetMeters);
      land.add(shore);
      sea.add(_offsetMeters(shore, seaBearing, offshoreMeters));
    }
    return (land: land, sea: sea);
  }

  static List<LatLng> _arcSectorPolygon({
    required List<LatLng> land,
    required List<LatLng> sea,
    required int start,
    required int end,
  }) {
    return [
      ...land.sublist(start, end + 1),
      ...sea.sublist(start, end + 1).reversed,
    ];
  }

  static LatLng _arcSectorLabel({
    required List<LatLng> land,
    required List<LatLng> sea,
    required int start,
    required int end,
  }) {
    final mid = (start + end) ~/ 2;
    return LatLng(
      (land[mid].latitude + sea[mid].latitude) / 2,
      (land[mid].longitude + sea[mid].longitude) / 2,
    );
  }

  /// Water-only marine sector: quadrilateral entirely seaward of the shore trace.
  static GulfCoastalBarangay _panaboWaterSector({
    required String zone,
    required String municipalityId,
    required String municipalityName,
    required String province,
    required String siteCode,
    required String barangayName,
    required String beachNote,
    required LatLng shoreWest,
    required LatLng shoreEast,
    double seaBearingDeg = 180,
    double nearshoreInsetMeters = 180,
    double offshoreMeters = 760,
  }) {
    final nearWest =
        _offsetMeters(shoreWest, seaBearingDeg, nearshoreInsetMeters);
    final nearEast =
        _offsetMeters(shoreEast, seaBearingDeg, nearshoreInsetMeters);
    final farWest = _offsetMeters(shoreWest, seaBearingDeg, offshoreMeters);
    final farEast = _offsetMeters(shoreEast, seaBearingDeg, offshoreMeters);
    final polygon = [nearWest, nearEast, farEast, farWest];
    final labelCenter = LatLng(
      (nearWest.latitude + farEast.latitude) / 2,
      (nearWest.longitude + farEast.longitude) / 2,
    );
    final slug = siteCode
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return GulfCoastalBarangay(
      id: '$municipalityId-$slug',
      siteCode: siteCode,
      name: barangayName,
      municipalityId: municipalityId,
      municipalityName: municipalityName,
      zoneCode: zone,
      province: province,
      centroid: labelCenter,
      polygon: polygon,
      beachNote: beachNote,
    );
  }

  /// Camera framing for Panabo marine-sector view (four gulf-facing barangays).
  static const LatLng panaboMarineSectorCenter = LatLng(7.2942, 125.7078);
  static const double panaboMarineSectorZoom = 13.1;

  /// Tight map envelope around coastal-site polygons (excludes inland LGU area).
  static List<LatLng> _coastalBoundaryFromSites(
    List<GulfCoastalBarangay> sites, {
    double padDegrees = 0.0018,
  }) {
    if (sites.isEmpty) return const [];
    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final site in sites) {
      for (final p in site.polygon) {
        minLat = math.min(minLat, p.latitude);
        maxLat = math.max(maxLat, p.latitude);
        minLng = math.min(minLng, p.longitude);
        maxLng = math.max(maxLng, p.longitude);
      }
    }
    return [
      LatLng(minLat - padDegrees, minLng - padDegrees),
      LatLng(maxLat + padDegrees, minLng - padDegrees),
      LatLng(maxLat + padDegrees, maxLng + padDegrees),
      LatLng(minLat - padDegrees, maxLng + padDegrees),
    ];
  }

  static int _closestCoastIndex(List<LatLng> coast, LatLng anchor) {
    var best = 0;
    var bestMeters = double.infinity;
    for (var i = 0; i < coast.length; i++) {
      final meters = _distance.as(LengthUnit.Meter, coast[i], anchor);
      if (meters < bestMeters) {
        bestMeters = meters;
        best = i;
      }
    }
    return best;
  }

  /// Slice bounds between ordered barangay shore anchors on a coast polyline.
  static List<int> _barangaySectorBounds(
    List<LatLng> coast,
    List<LatLng> barangayAnchors,
  ) {
    final anchorIdx = <int>[
      for (final anchor in barangayAnchors) _closestCoastIndex(coast, anchor),
    ];
    for (var i = 1; i < anchorIdx.length; i++) {
      if (anchorIdx[i] <= anchorIdx[i - 1]) {
        anchorIdx[i] = anchorIdx[i - 1] + 1;
      }
    }
    return [
      0,
      (anchorIdx[0] + anchorIdx[1]) ~/ 2,
      (anchorIdx[1] + anchorIdx[2]) ~/ 2,
      (anchorIdx[2] + anchorIdx[3]) ~/ 2,
      coast.length - 1,
    ];
  }

  /// Irregular nearshore survey quadrilateral (thin beach strip + open water).
  static List<LatLng> nearshoreSurveyPatch(
    LatLng shoreAnchor, {
    double seaBearingDeg = 90,
    double alongShoreMeters = 280,
    double offshoreMeters = 320,
  }) {
    final along = (seaBearingDeg + 90) % 360;
    final inland = (seaBearingDeg + 180) % 360;
    final half = alongShoreMeters / 2;
    const skew = 0.18;
    // Minimal land footprint; bulk of patch sits in the water.
    final landMid = _offsetMeters(shoreAnchor, inland, 12);
    final seaMid = _offsetMeters(shoreAnchor, seaBearingDeg, offshoreMeters);
    return [
      _offsetMeters(landMid, along, half * (1 - skew)),
      _offsetMeters(landMid, (along + 180) % 360, half),
      _offsetMeters(seaMid, (along + 180) % 360, half * (1 + skew)),
      _offsetMeters(seaMid, along, half * (1 - skew * 0.5)),
    ];
  }

  static LatLng _offsetMeters(LatLng from, double bearingDeg, double meters) {
    return _distance.offset(from, meters, bearingDeg);
  }

  static double _defaultSeaBearing(String zoneCode) {
    switch (zoneCode) {
      case 'A':
      case 'B':
      case 'D':
      case 'L':
      case 'M':
        return 180;
      case 'N':
      case 'O':
      case 'P':
      case 'Q':
        return 270;
      default:
        return 0;
    }
  }

  static bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;
      final intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude <
              (xj - xi) * (point.latitude - yi) / (yj - yi + 1e-12) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  static GulfCoastalBarangay _coastalSite(
    String zoneCode,
    String municipalityId,
    String municipalityName,
    String province,
    String siteCode,
    String name,
    LatLng shoreAnchor, {
    String? beachNote,
    double? seaBearingDeg,
    double alongShoreMeters = 560,
    double offshoreMeters = 400,
  }) {
    final bearing = seaBearingDeg ?? _defaultSeaBearing(zoneCode);
    final polygon = nearshoreSurveyPatch(
      shoreAnchor,
      seaBearingDeg: bearing,
      alongShoreMeters: alongShoreMeters,
      offshoreMeters: offshoreMeters,
    );
    final slug = siteCode
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    // Label centroid = geometric center of marine polygon (not offshore pin).
    var lat = 0.0, lng = 0.0;
    for (final p in polygon) {
      lat += p.latitude;
      lng += p.longitude;
    }
    final labelCenter = LatLng(lat / polygon.length, lng / polygon.length);
    return GulfCoastalBarangay(
      id: '$municipalityId-$slug',
      siteCode: siteCode,
      name: name,
      municipalityId: municipalityId,
      municipalityName: municipalityName,
      zoneCode: zoneCode,
      province: province,
      centroid: labelCenter,
      polygon: polygon,
      beachNote: beachNote,
    );
  }

  static GulfCoastalBarangay _coastalSectorSite(
    String zoneCode,
    String municipalityId,
    String municipalityName,
    String province,
    String siteCode,
    String name,
    List<LatLng> coastSlice, {
    String? beachNote,
    double preferredSeaBearingDeg = 95,
    double offshoreMeters = 880,
  }) {
    final polygon = coastalSectorStripPolygon(
      coastPoints: coastSlice,
      preferredSeaBearingDeg: preferredSeaBearingDeg,
      offshoreMeters: offshoreMeters,
    );
    final labelCenter = _marineSectorLabelPoint(
      coastSlice,
      preferredSeaBearingDeg: preferredSeaBearingDeg,
      offshoreMeters: offshoreMeters,
    );
    final slug = siteCode
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return GulfCoastalBarangay(
      id: '$municipalityId-$slug',
      siteCode: siteCode,
      name: name,
      municipalityId: municipalityId,
      municipalityName: municipalityName,
      zoneCode: zoneCode,
      province: province,
      centroid: labelCenter,
      polygon: polygon,
      beachNote: beachNote,
    );
  }

  static GulfCoastalMunicipality _municipality({
    required String zoneCode,
    required String id,
    required String name,
    required String province,
    required String kind,
    required double lat,
    required double lng,
    required List<GulfCoastalBarangay> barangays,
    List<LatLng>? boundary,
    String? reference,
    bool marineSectorLayout = false,
  }) {
    return GulfCoastalMunicipality(
      id: id,
      zoneCode: zoneCode,
      name: name,
      province: province,
      kind: kind,
      centroid: LatLng(lat, lng),
      boundary: boundary ?? _coastalBoundaryFromSites(barangays),
      barangays: barangays,
      reference: reference,
      marineSectorLayout: marineSectorLayout,
    );
  }

  static List<GulfCoastalMunicipality> _buildMunicipalities() {
    return [
      _panaboCity(),
      _tagumCity(),
      _samalCity(),
      _carmenMunicipality(),
      _davaoCity(),
      _digosCity(),
      _santaCruzMunicipality(),
      _hagonoyMunicipality(),
      _padadaMunicipality(),
      _malalagMunicipality(),
      _sulopMunicipality(),
      _macoMunicipality(),
      _pantukanMunicipality(),
      _banaybanayMunicipality(),
      _luponMunicipality(),
      _sanIsidroOrientalMunicipality(),
      _governorGenerosoMunicipality(),
    ];
  }

  static GulfCoastalMunicipality _panaboCity() {
    const zone = 'A';
    const id = 'panabo-city';
    const name = 'Panabo City';
    const province = 'Davao del Norte';
    const lat = 7.2978;
    const lng = 125.7078;
    // North-shore Panabo: Davao Gulf is south. Shore trace sits on the waterline;
    // every sector vertex is offset south so polygons stay in the water only.
    const seaBearing = 180.0;

    final barangays = [
      _panaboWaterSector(
        zone: zone,
        municipalityId: id,
        municipalityName: name,
        province: province,
        siteCode: 'A-01',
        barangayName: 'Brgy. J. P. Laurel',
        beachNote: 'Monitoring sector — coastal waters off J.P. Laurel',
        shoreWest: const LatLng(7.2974, 125.6955),
        shoreEast: const LatLng(7.2971, 125.7002),
        seaBearingDeg: seaBearing,
        nearshoreInsetMeters: 200,
      ),
      _panaboWaterSector(
        zone: zone,
        municipalityId: id,
        municipalityName: name,
        province: province,
        siteCode: 'A-02',
        barangayName: 'Brgy. Cagangohan',
        beachNote: 'Monitoring sector — coastal waters off Cagangohan',
        shoreWest: const LatLng(7.2971, 125.7002),
        shoreEast: const LatLng(7.2968, 125.7058),
        seaBearingDeg: seaBearing,
        nearshoreInsetMeters: 200,
      ),
      _panaboWaterSector(
        zone: zone,
        municipalityId: id,
        municipalityName: name,
        province: province,
        siteCode: 'A-03',
        barangayName: 'Brgy. Salvacion',
        beachNote: 'Monitoring sector — coastal waters off Salvacion wharf',
        shoreWest: const LatLng(7.2968, 125.7058),
        shoreEast: const LatLng(7.2964, 125.7125),
        seaBearingDeg: seaBearing,
        nearshoreInsetMeters: 200,
      ),
      _panaboWaterSector(
        zone: zone,
        municipalityId: id,
        municipalityName: name,
        province: province,
        siteCode: 'A-04',
        barangayName: 'Brgy. Tibungol',
        beachNote: 'Monitoring sector — coastal waters off Tibungol port coast',
        shoreWest: const LatLng(7.2964, 125.7125),
        shoreEast: const LatLng(7.2960, 125.7198),
        seaBearingDeg: seaBearing,
        nearshoreInsetMeters: 200,
      ),
    ];
    return _municipality(
      zoneCode: zone,
      id: id,
      name: name,
      province: province,
      kind: 'City',
      lat: lat,
      lng: lng,
      barangays: barangays,
      marineSectorLayout: true,
      reference:
          'Zone A · Gulf-facing coastal barangays only (Laurel, Cagangohan, Salvacion, Tibungol)',
    );
  }

  static GulfCoastalMunicipality _tagumCity() {
    const zone = 'B';
    const id = 'tagum-city';
    const name = 'Tagum City';
    const province = 'Davao del Norte';
    const lat = 7.4020;
    const lng = 125.7780;
    // Tagum I'M SEACURe / UP coastal hazard study — gulf-facing barangays only.
    final barangays = [
      _coastalSite(zone, id, name, province, 'B-01', 'Brgy. Madaum',
          const LatLng(7.4280, 125.7920),
          beachNote: 'Mangrove coast & reef flat along Davao Gulf'),
      _coastalSite(zone, id, name, province, 'B-02', 'Brgy. Busaon',
          const LatLng(7.3548, 125.7520),
          beachNote: 'Lower Busaon fisherfolk coast / nearshore reef'),
      _coastalSite(zone, id, name, province, 'B-03', 'Brgy. Liboganon',
          const LatLng(7.3685, 125.7640),
          beachNote: 'Liboganon River mouth; brackish reef fringe'),
      _coastalSite(zone, id, name, province, 'B-04', 'Brgy. Bincungan',
          const LatLng(7.3820, 125.7760),
          beachNote: 'Coastal barangay; shallow reef & mangrove belt'),
    ];
    return _municipality(
      zoneCode: zone,
      id: id,
      name: name,
      province: province,
      kind: 'City',
      lat: lat,
      lng: lng,
      boundary: const [
        LatLng(7.342, 125.742),
        LatLng(7.448, 125.746),
        LatLng(7.452, 125.812),
        LatLng(7.346, 125.816),
      ],
      barangays: barangays,
      reference: 'Zone B · documented Tagum Gulf-coast barangays',
    );
  }

  static GulfCoastalMunicipality _samalCity() {
    const zone = 'C';
    const id = 'samal-city';
    const name = 'Island Garden City of Samal';
    const province = 'Davao del Norte';
    const lat = 7.0744;
    const lng = 125.7088;
    // Beach / resort / reef-flat barangays only (UP coastal hazard study).
    final barangays = [
      _coastalSite(zone, id, name, province, 'C-01', 'Brgy. Poblacion (Kaputian)',
          const LatLng(7.0535, 125.6970), seaBearingDeg: 270,
          beachNote: 'Kaputian Beach Park; fringing reef'),
      _coastalSite(zone, id, name, province, 'C-02', 'Brgy. San Remigio',
          const LatLng(7.0480, 125.6890), seaBearingDeg: 270,
          beachNote: 'Kaputian west coast; coral reef flat'),
      _coastalSite(zone, id, name, province, 'C-03', 'Brgy. San Isidro (Kaputian)',
          const LatLng(7.0610, 125.7050), seaBearingDeg: 270,
          beachNote: 'Kaputian coast; nearshore reef'),
      _coastalSite(zone, id, name, province, 'C-04', 'Brgy. Peñaplata (Poblacion)',
          const LatLng(7.0990, 125.7150), seaBearingDeg: 90,
          beachNote: 'Samal District west-facing beach strip'),
      _coastalSite(zone, id, name, province, 'C-05', 'Brgy. Tambo',
          const LatLng(7.1180, 125.7320), seaBearingDeg: 90,
          beachNote: 'Vanishing Island; white-sand reef flat'),
      _coastalSite(zone, id, name, province, 'C-06', 'Brgy. Adecor',
          const LatLng(7.1120, 125.7380), seaBearingDeg: 90,
          beachNote: 'Resort coast; shallow reef'),
      _coastalSite(zone, id, name, province, 'C-07', 'Brgy. Tagpopongan',
          const LatLng(7.0720, 125.7520), seaBearingDeg: 90,
          beachNote: 'East coast beach & reef flat'),
      _coastalSite(zone, id, name, province, 'C-08', 'Brgy. Cogon (Talikud)',
          const LatLng(6.9840, 125.7080), seaBearingDeg: 90,
          beachNote: 'Talikud Island beach coast'),
      _coastalSite(zone, id, name, province, 'C-09', 'Brgy. Santa Cruz (Talikud)',
          const LatLng(6.9760, 125.7180), seaBearingDeg: 90,
          beachNote: 'Talikud Island reef / dive coast'),
    ];
    return _municipality(
      zoneCode: zone,
      id: id,
      name: name,
      province: province,
      kind: 'City',
      lat: lat,
      lng: lng,
      boundary: const [
        LatLng(6.955, 125.665),
        LatLng(7.135, 125.668),
        LatLng(7.138, 125.770),
        LatLng(6.958, 125.768),
      ],
      barangays: barangays,
      reference: 'Zone C · Samal beach & reef-flat barangays only',
    );
  }

  static GulfCoastalMunicipality _carmenMunicipality() {
    const zone = 'D';
    const id = 'carmen';
    const name = 'Carmen';
    const province = 'Davao del Norte';
    const lat = 7.3556;
    const lng = 125.7180;
    // UP coastal hazard study — Carmen Gulf-facing barangays.
    final barangays = [
      _coastalSite(zone, id, name, province, 'D-01', 'Brgy. Taba',
          const LatLng(7.3620, 125.7220),
          beachNote: 'Gulf coast; reef flat & mangrove fringe'),
      _coastalSite(zone, id, name, province, 'D-02', 'Brgy. Lapaz (La Suerte)',
          const LatLng(7.3520, 125.7280),
          beachNote: 'Coastal barangay; nearshore reef area'),
      _coastalSite(zone, id, name, province, 'D-03', 'Brgy. Tubod',
          const LatLng(7.3480, 125.7140),
          beachNote: 'Tubod coast; shallow reef & fisherfolk area'),
    ];
    return _municipality(
      zoneCode: zone,
      id: id,
      name: name,
      province: province,
      kind: 'Municipality',
      lat: lat,
      lng: lng,
      boundary: const [
        LatLng(7.332, 125.698),
        LatLng(7.372, 125.702),
        LatLng(7.376, 125.742),
        LatLng(7.336, 125.746),
      ],
      barangays: barangays,
      reference: 'Zone D · Carmen Gulf-coast barangays only',
    );
  }

  static GulfCoastalMunicipality _davaoCity() {
    const zone = 'E';
    const id = 'davao-city';
    const name = 'Davao City';
    const province = 'Davao del Sur';
    const lat = 7.0600;
    const lng = 125.5200;
    // Davao City CRM coastal barangays with beach / reef / aplaya — no upland poblacion.
    const sites = <(String name, LatLng shore, String note)>[
      ('Brgy. Binugao', const LatLng(6.9578, 125.4085), 'Southern coast; reef flat'),
      ('Brgy. Sirawan', const LatLng(6.9715, 125.4180), 'Beach coast; nearshore reef'),
      ('Brgy. Dumoy', const LatLng(6.9845, 125.4285), 'Coastal barangay; reef fringe'),
      ('Brgy. Talomo Proper', const LatLng(7.0075, 125.4545), 'Talomo coast; reef area'),
      ('Brgy. Matina Aplaya', const LatLng(7.0275, 125.4775), 'Public beach; reef flat'),
      ('Brgy. Bago Aplaya', const LatLng(7.0375, 125.4915), 'Aplaya coast; shallow reef'),
      ('Brgy. 76-A (Bucana)', const LatLng(7.0475, 125.5045), 'Bucana coast; reef fringe'),
      ('Brgy. Daliao', const LatLng(7.0525, 125.5175), 'Coastal reef flat'),
      ('Brgy. Lizada', const LatLng(7.0555, 125.5275), 'Nearshore reef coast'),
      ('Brgy. Ilang', const LatLng(7.0585, 125.5375), 'Coastal reef & mangrove'),
      ('Brgy. Tibungco', const LatLng(7.0655, 125.5475), 'Gulf-facing coast'),
      ('Brgy. Bunawan', const LatLng(7.0755, 125.5545), 'River mouth / reef flat'),
      ('Brgy. Lasang', const LatLng(7.0885, 125.5615), 'Lasang coast; reef area'),
      ('Brgy. Panacan', const LatLng(7.0985, 125.5675), 'Coastal reef fringe'),
      ('Brgy. Sasa', const LatLng(7.1085, 125.5775), 'Sasa wharf reef flat'),
      ('Brgy. Pampanga', const LatLng(7.1155, 125.5845), 'Coastal nearshore reef'),
      ('Brgy. Vicente Hizon Sr.', const LatLng(7.1225, 125.5915), 'East coast reef flat'),
    ];
    final barangays = <GulfCoastalBarangay>[
      for (var i = 0; i < sites.length; i++)
        _coastalSite(
          zone,
          id,
          name,
          province,
          'E-${(i + 1).toString().padLeft(2, '0')}',
          sites[i].$1,
          sites[i].$2,
          beachNote: sites[i].$3,
        ),
    ];
    return _municipality(
      zoneCode: zone,
      id: id,
      name: name,
      province: province,
      kind: 'City',
      lat: lat,
      lng: lng,
      boundary: const [
        LatLng(6.948, 125.398),
        LatLng(7.128, 125.392),
        LatLng(7.132, 125.602),
        LatLng(6.952, 125.608),
      ],
      barangays: barangays,
      reference: 'Zone E · Davao City CRM beach/reef coastal barangays',
    );
  }

  static GulfCoastalMunicipality _digosCity() {
    const zone = 'F';
    const id = 'digos-city';
    const name = 'Digos City';
    const province = 'Davao del Sur';
    const lat = 6.7420;
    const lng = 125.3580;
    final barangays = [
      _coastalSite(zone, id, name, province, 'F-01', 'Brgy. Aplaya',
          const LatLng(6.7380, 125.3580),
          beachNote: 'Public beach; nearshore reef flat'),
      _coastalSite(zone, id, name, province, 'F-02', 'Brgy. Sta. Maria',
          const LatLng(6.7280, 125.3520),
          beachNote: 'Little Boracay; white-sand reef coast'),
    ];
    return _municipality(
      zoneCode: zone,
      id: id,
      name: name,
      province: province,
      kind: 'City',
      lat: lat,
      lng: lng,
      boundary: const [
        LatLng(6.718, 125.338),
        LatLng(6.758, 125.334),
        LatLng(6.762, 125.372),
        LatLng(6.722, 125.376),
      ],
      barangays: barangays,
      reference: 'Zone F · Digos beach barangays only',
    );
  }

  static GulfCoastalMunicipality _santaCruzMunicipality() {
    const zone = 'G';
    const id = 'santa-cruz';
    const name = 'Santa Cruz';
    const province = 'Davao del Sur';
    const lat = 6.8280;
    const lng = 125.4120;
    final barangays = [
      _coastalSite(zone, id, name, province, 'G-01', 'Brgy. Aplaya',
          const LatLng(6.8260, 125.4060),
          beachNote: 'Gulf-facing beach; reef flat'),
      _coastalSite(zone, id, name, province, 'G-02', 'Brgy. Saliduque',
          const LatLng(6.8200, 125.4220),
          beachNote: 'Coastal reef & mangrove fringe'),
    ];
    return _municipality(
      zoneCode: zone,
      id: id,
      name: name,
      province: province,
      kind: 'Municipality',
      lat: lat,
      lng: lng,
      boundary: const [
        LatLng(6.808, 125.392),
        LatLng(6.848, 125.388),
        LatLng(6.852, 125.432),
        LatLng(6.812, 125.436),
      ],
      barangays: barangays,
      reference: 'Zone G · Santa Cruz Gulf-coast barangays only',
    );
  }

  static GulfCoastalMunicipality _hagonoyMunicipality() {
    const zone = 'H';
    const id = 'hagonoy';
    const name = 'Hagonoy';
    const province = 'Davao del Sur';
    const lat = 6.6860;
    const lng = 125.3080;
    final barangays = [
      _coastalSite(zone, id, name, province, 'H-01', 'Brgy. Aplaya',
          const LatLng(6.6820, 125.3080),
          beachNote: 'Eastern gulf beach; reef flat'),
      _coastalSite(zone, id, name, province, 'H-02', 'Brgy. Guihing Aplaya',
          const LatLng(6.6900, 125.3140),
          beachNote: 'Named aplaya coast; shallow reef'),
      _coastalSite(zone, id, name, province, 'H-03', 'Brgy. Leling',
          const LatLng(6.6780, 125.3020),
          beachNote: 'Coastal reef fringe along Davao Gulf'),
    ];
    return _municipality(
      zoneCode: zone,
      id: id,
      name: name,
      province: province,
      kind: 'Municipality',
      lat: lat,
      lng: lng,
      boundary: const [
        LatLng(6.668, 125.288),
        LatLng(6.702, 125.284),
        LatLng(6.706, 125.328),
        LatLng(6.672, 125.332),
      ],
      barangays: barangays,
      reference: 'Zone H · Hagonoy aplaya / reef coast barangays',
    );
  }

  static GulfCoastalMunicipality _padadaMunicipality() {
    const zone = 'I';
    const id = 'padada';
    const name = 'Padada';
    const province = 'Davao del Sur';
    const lat = 6.6360;
    const lng = 125.3480;
    final barangays = [
      _coastalSite(zone, id, name, province, 'I-01', 'Brgy. NCOF',
          const LatLng(6.6450, 125.3500),
          beachNote: 'Gulf-facing coast; nearshore reef'),
      _coastalSite(zone, id, name, province, 'I-02', 'Brgy. Harada Butai',
          const LatLng(6.6280, 125.3520),
          beachNote: 'Coastal reef flat & fisherfolk area'),
    ];
    return _municipality(
      zoneCode: zone,
      id: id,
      name: name,
      province: province,
      kind: 'Municipality',
      lat: lat,
      lng: lng,
      boundary: const [
        LatLng(6.618, 125.332),
        LatLng(6.652, 125.328),
        LatLng(6.656, 125.362),
        LatLng(6.622, 125.366),
      ],
      barangays: barangays,
      reference: 'Zone I · Padada Gulf-coast barangays only',
    );
  }

  static GulfCoastalMunicipality _malalagMunicipality() {
    const zone = 'J';
    const id = 'malalag';
    const name = 'Malalag';
    const province = 'Davao del Sur';
    const lat = 6.5620;
    const lng = 125.4080;
    final barangays = [
      _coastalSite(zone, id, name, province, 'J-01', 'Brgy. New Visayas',
          const LatLng(6.5580, 125.4080),
          beachNote: 'Gulf coast beach strip'),
      _coastalSite(zone, id, name, province, 'J-02', 'Brgy. Bagatelle',
          const LatLng(6.5750, 125.4140),
          beachNote: 'Coastal reef flat'),
      _coastalSite(zone, id, name, province, 'J-03', 'Brgy. Lunib',
          const LatLng(6.5520, 125.4000),
          beachNote: 'Nearshore reef & mangrove coast'),
    ];
    return _municipality(
      zoneCode: zone,
      id: id,
      name: name,
      province: province,
      kind: 'Municipality',
      lat: lat,
      lng: lng,
      boundary: const [
        LatLng(6.538, 125.384),
        LatLng(6.582, 125.380),
        LatLng(6.586, 125.428),
        LatLng(6.542, 125.432),
      ],
      barangays: barangays,
      reference: 'Zone J · Malalag Gulf-coast barangays only',
    );
  }

  static GulfCoastalMunicipality _sulopMunicipality() {
    const zone = 'K';
    const id = 'sulop';
    const name = 'Sulop';
    const province = 'Davao del Sur';
    const lat = 6.5920;
    const lng = 125.3480;
    final barangays = [
      _coastalSite(zone, id, name, province, 'K-01', 'Brgy. Davao',
          const LatLng(6.5920, 125.3480),
          beachNote: 'Gulf-facing barangay; coastal reef fringe'),
      _coastalSite(zone, id, name, province, 'K-02', 'Brgy. Balasinon',
          const LatLng(6.5880, 125.3360),
          beachNote: 'Nearshore coast; shallow reef flat'),
    ];
    return _municipality(
      zoneCode: zone,
      id: id,
      name: name,
      province: province,
      kind: 'Municipality',
      lat: lat,
      lng: lng,
      boundary: const [
        LatLng(6.578, 125.322),
        LatLng(6.608, 125.318),
        LatLng(6.612, 125.358),
        LatLng(6.582, 125.362),
      ],
      barangays: barangays,
      reference: 'Zone K · Sulop Gulf-coast barangays only',
    );
  }

  static GulfCoastalMunicipality _macoMunicipality() {
    const zone = 'L';
    const id = 'maco';
    const name = 'Maco';
    const province = 'Davao de Oro';
    const lat = 7.3650;
    const lng = 125.8520;
    final barangays = [
      _coastalSite(zone, id, name, province, 'L-01', 'Brgy. Bucana',
          const LatLng(7.3620, 125.8440),
          beachNote: 'Gold Coast beach; reef flat'),
      _coastalSite(zone, id, name, province, 'L-02', 'Brgy. Hijo',
          const LatLng(7.3780, 125.8580),
          beachNote: 'Hijo Resources coast; reef & beach'),
      _coastalSite(zone, id, name, province, 'L-03', 'Brgy. Panibasan',
          const LatLng(7.3550, 125.8680),
          beachNote: 'Gulf coast; nearshore reef'),
      _coastalSite(zone, id, name, province, 'L-04', 'Brgy. Taglawig',
          const LatLng(7.3480, 125.8340),
          beachNote: 'Coastal reef fringe'),
    ];
    return _municipality(
      zoneCode: zone,
      id: id,
      name: name,
      province: province,
      kind: 'Municipality',
      lat: lat,
      lng: lng,
      boundary: const [
        LatLng(7.336, 125.822),
        LatLng(7.386, 125.818),
        LatLng(7.390, 125.878),
        LatLng(7.340, 125.882),
      ],
      barangays: barangays,
      reference: 'Zone L · Maco beach / resort coast barangays',
    );
  }

  static GulfCoastalMunicipality _pantukanMunicipality() {
    const zone = 'M';
    const id = 'pantukan';
    const name = 'Pantukan';
    const province = 'Davao de Oro';
    const lat = 7.1280;
    const lng = 125.8980;
    final barangays = [
      _coastalSite(zone, id, name, province, 'M-01', 'Brgy. Napnapan',
          const LatLng(7.1180, 125.8840),
          beachNote: 'Gulf coast; reef flat'),
      _coastalSite(zone, id, name, province, 'M-02', 'Brgy. Tambongon',
          const LatLng(7.1380, 125.9000),
          beachNote: 'Coastal nearshore reef area'),
      _coastalSite(zone, id, name, province, 'M-03', 'Brgy. Kingking',
          const LatLng(7.1450, 125.9080),
          beachNote: 'Kingking coast; shallow reef'),
    ];
    return _municipality(
      zoneCode: zone,
      id: id,
      name: name,
      province: province,
      kind: 'Municipality',
      lat: lat,
      lng: lng,
      boundary: const [
        LatLng(7.108, 125.872),
        LatLng(7.152, 125.868),
        LatLng(7.156, 125.918),
        LatLng(7.112, 125.922),
      ],
      barangays: barangays,
      reference: 'Zone M · Pantukan Gulf-coast barangays only',
    );
  }

  static GulfCoastalMunicipality _banaybanayMunicipality() {
    const zone = 'N';
    const id = 'banaybanay';
    const name = 'Banaybanay';
    const province = 'Davao Oriental';
    const lat = 6.9580;
    const lng = 126.0040;
    final barangays = [
      _coastalSite(zone, id, name, province, 'N-01', 'Brgy. Bonhomie',
          const LatLng(6.9550, 126.0080), seaBearingDeg: 270,
          beachNote: 'Bonhomie white-sand beach; reef flat'),
      _coastalSite(zone, id, name, province, 'N-02', 'Brgy. San Vicente',
          const LatLng(6.9680, 126.0140), seaBearingDeg: 270,
          beachNote: 'Coastal reef & beach strip'),
      _coastalSite(zone, id, name, province, 'N-03', 'Brgy. Cabangcalan',
          const LatLng(6.9520, 125.9980), seaBearingDeg: 270,
          beachNote: 'Gulf-facing coast; nearshore reef'),
    ];
    return _municipality(
      zoneCode: zone,
      id: id,
      name: name,
      province: province,
      kind: 'Municipality',
      lat: lat,
      lng: lng,
      boundary: const [
        LatLng(6.938, 125.982),
        LatLng(6.978, 125.978),
        LatLng(6.982, 126.022),
        LatLng(6.942, 126.026),
      ],
      barangays: barangays,
      reference: 'Zone N · Banaybanay beach coast barangays',
    );
  }

  static GulfCoastalMunicipality _luponMunicipality() {
    const zone = 'O';
    const id = 'lupon';
    const name = 'Lupon';
    const province = 'Davao Oriental';
    const lat = 6.8980;
    const lng = 126.0140;
    final barangays = [
      _coastalSite(zone, id, name, province, 'O-01', 'Brgy. Tagugpo',
          const LatLng(6.8960, 126.0180), seaBearingDeg: 270,
          beachNote: 'Coastal reef flat'),
      _coastalSite(zone, id, name, province, 'O-02', 'Brgy. Calapagan',
          const LatLng(6.8920, 126.0040), seaBearingDeg: 270,
          beachNote: 'Gulf-facing beach coast'),
      _coastalSite(zone, id, name, province, 'O-03', 'Brgy. Marayag',
          const LatLng(6.9180, 126.0240), seaBearingDeg: 270,
          beachNote: 'Nearshore reef & mangrove coast'),
    ];
    return _municipality(
      zoneCode: zone,
      id: id,
      name: name,
      province: province,
      kind: 'Municipality',
      lat: lat,
      lng: lng,
      boundary: const [
        LatLng(6.882, 125.988),
        LatLng(6.928, 125.984),
        LatLng(6.932, 126.034),
        LatLng(6.886, 126.038),
      ],
      barangays: barangays,
      reference: 'Zone O · Lupon Gulf-coast barangays only',
    );
  }

  static GulfCoastalMunicipality _sanIsidroOrientalMunicipality() {
    const zone = 'P';
    const id = 'san-isidro-do';
    const name = 'San Isidro';
    const province = 'Davao Oriental';
    const lat = 6.8352;
    const lng = 126.0895;
    // All seven documented coastline barangays (municipal coastal profile).
    final barangays = [
      _coastalSite(zone, id, name, province, 'P-01', 'Brgy. Talisay',
          const LatLng(6.8380, 126.0900), seaBearingDeg: 270,
          beachNote: 'Coastline barangay; reef flat'),
      _coastalSite(zone, id, name, province, 'P-02', 'Brgy. Lapu-lapu',
          const LatLng(6.8320, 126.0840), seaBearingDeg: 270,
          beachNote: 'Gulf-facing coast; nearshore reef'),
      _coastalSite(zone, id, name, province, 'P-03', 'Brgy. Maputi',
          const LatLng(6.8280, 126.0960), seaBearingDeg: 270,
          beachNote: 'Beach coast; shallow reef'),
      _coastalSite(zone, id, name, province, 'P-04', 'Brgy. Bitaogan',
          const LatLng(6.8420, 126.0800), seaBearingDeg: 270,
          beachNote: 'Coastal reef fringe'),
      _coastalSite(zone, id, name, province, 'P-05', 'Brgy. Baon',
          const LatLng(6.8480, 126.0930), seaBearingDeg: 270,
          beachNote: 'Nearshore reef coast'),
      _coastalSite(zone, id, name, province, 'P-06', 'Brgy. San Miguel',
          const LatLng(6.8240, 126.0860), seaBearingDeg: 270,
          beachNote: 'Coastline barangay; reef flat'),
      _coastalSite(zone, id, name, province, 'P-07', 'Brgy. Batobato (Poblacion)',
          const LatLng(6.8360, 126.0880), seaBearingDeg: 270,
          beachNote: 'Poblacion on gulf coast; reef & beach'),
    ];
    return _municipality(
      zoneCode: zone,
      id: id,
      name: name,
      province: province,
      kind: 'Municipality',
      lat: lat,
      lng: lng,
      boundary: const [
        LatLng(6.812, 126.062),
        LatLng(6.858, 126.058),
        LatLng(6.862, 126.108),
        LatLng(6.816, 126.112),
      ],
      barangays: barangays,
      reference: 'Zone P · San Isidro documented coastline barangays',
    );
  }

  static GulfCoastalMunicipality _governorGenerosoMunicipality() {
    const zone = 'Q';
    const id = 'governor-generoso';
    const name = 'Governor Generoso';
    const province = 'Davao Oriental';
    const lat = 6.6584;
    const lng = 126.0798;
    final barangays = [
      _coastalSite(zone, id, name, province, 'Q-01', 'Brgy. Tamban',
          const LatLng(6.6520, 126.0800), seaBearingDeg: 270,
          beachNote: 'Gulf coast beach; reef flat'),
      _coastalSite(zone, id, name, province, 'Q-02', 'Brgy. Tibanban',
          const LatLng(6.6680, 126.0840), seaBearingDeg: 270,
          beachNote: 'Coastal nearshore reef'),
      _coastalSite(zone, id, name, province, 'Q-03', 'Brgy. Lavigan',
          const LatLng(6.6450, 126.0700), seaBearingDeg: 270,
          beachNote: 'Beach coast; shallow reef'),
      _coastalSite(zone, id, name, province, 'Q-04', 'Brgy. Montserrat',
          const LatLng(6.6720, 126.0680), seaBearingDeg: 270,
          beachNote: 'Gulf-facing reef fringe'),
    ];
    return _municipality(
      zoneCode: zone,
      id: id,
      name: name,
      province: province,
      kind: 'Municipality',
      lat: lat,
      lng: lng,
      boundary: const [
        LatLng(6.632, 126.052),
        LatLng(6.682, 126.048),
        LatLng(6.686, 126.092),
        LatLng(6.636, 126.096),
      ],
      barangays: barangays,
      reference: 'Zone Q · Governor Generoso Gulf-coast barangays',
    );
  }
}
