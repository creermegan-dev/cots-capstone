import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:latlong2/latlong.dart';

/// Davao Gulf monitoring map (Stage 6, `cots-davao-gulf-v2`).
///
/// Zone = a city or town (letter A–V). Area = the water of one coastal
/// barangay (A1, A2 …). Part = about 1.1 ha of reef inside an area
/// (A2-1, A2-2 …), the unit one Diver owns. An area with no mapped reef is one
/// whole part (for example `K10`).
///
/// Every area runs from the shoreline to the reef edge plus a 50 m margin,
/// water only. A location belongs to the part that contains it, or to the
/// nearest part within 15 m (GPS allowance). The database uses the same
/// lookup (`cots_private.area_at`), so the phone and the server always agree.
///
/// Sources: Allen Coral Atlas (2020) geomorphic map, CC BY 4.0
/// (doi.org/10.5281/zenodo.3833242); barangay boundaries NAMRIA/PSA via OCHA
/// COD-AB; part size Chandler et al. (2023), Sci Rep 13:19306.
/// Generated files: assets/map/*.json, assets/map/lookup.bin.

/// One monitoring part (the unit a Diver owns), e.g. `V3-12 · Balet Part 12`.
class GulfCoastalBarangay {
  GulfCoastalBarangay._({
    required this.index,
    required this.id,
    required this.areaCode,
    required this.partNo,
    required this.name,
    required this.municipalityId,
    required this.municipalityName,
    required this.zoneCode,
    required this.psgc,
    required this.reefHectares,
    required this.centroid,
  });

  final int index;

  /// Part code, e.g. `V3-12` (or the area code when the area is one part).
  final String id;

  /// Area code, e.g. `V3`.
  final String areaCode;

  /// Part number inside the area; 0 when the whole area is one part.
  final int partNo;

  /// Barangay name, e.g. `Balet`.
  final String name;
  final String municipalityId;
  final String municipalityName;
  final String zoneCode;

  /// Official barangay code (PSGC).
  final String psgc;

  /// Shallow reef inside this part (hectares).
  final double reefHectares;
  final LatLng centroid;

  String get siteCode => id;
  String get province => '';
  String? get beachNote => null;
  String get displayLabel => id;

  /// Full name as stored in the database, e.g. `V3-12 · Balet Part 12`.
  String get displayName =>
      partNo > 0 ? '$id · $name Part $partNo' : '$id · $name';
  String get subtitle => '$displayName · $municipalityName';
  String get zoneLabel => 'Zone $zoneCode';

  /// Outline rings of this part (largest first).
  List<List<LatLng>> get rings => DavaoGulfGeography._partRings(index);

  /// Largest outline ring, for drawing.
  List<LatLng> get polygon {
    final r = rings;
    return r.isEmpty ? const <LatLng>[] : r.first;
  }
}

/// One coastal barangay's water (an area), e.g. `V3 · Balet`.
class GulfMonitoringArea {
  GulfMonitoringArea._({
    required this.code,
    required this.zoneCode,
    required this.barangay,
    required this.rings,
    required this.parts,
    required this.centroid,
  });

  final String code;
  final String zoneCode;
  final String barangay;
  final List<List<LatLng>> rings;
  final List<GulfCoastalBarangay> parts;
  final LatLng centroid;

  String get displayName => '$code · $barangay';
}

/// City/municipality along Davao Gulf (a zone).
class GulfCoastalMunicipality {
  GulfCoastalMunicipality._({
    required this.id,
    required this.zoneCode,
    required this.name,
    required this.centroid,
    required this.boundary,
    required this.areas,
    required this.barangays,
  });

  final String id;

  /// Letter shown on the map, e.g. `A` for Panabo City.
  final String zoneCode;
  final String name;
  final LatLng centroid;

  /// Outline around all of this zone's areas (for the overview map).
  final List<LatLng> boundary;
  final List<GulfMonitoringArea> areas;

  /// All parts in this zone.
  final List<GulfCoastalBarangay> barangays;

  String get province => '';
  String get kind => 'municipality';
  String? get reference => null;
  bool get marineSectorLayout => false;
  String get zoneLabel => 'Zone $zoneCode';
  int get barangayCount => barangays.length;
}

/// Result of a location lookup.
class GulfZoneAssignment {
  const GulfZoneAssignment({
    required this.municipality,
    required this.barangay,
    required this.zoneLabel,
  });

  final GulfCoastalMunicipality municipality;

  /// The part.
  final GulfCoastalBarangay barangay;
  final String zoneLabel;
}

abstract final class DavaoGulfGeography {
  static const version = 'cots-davao-gulf-v2';
  static const allowanceMeters = 15.0;
  static const _lat0 = 6.6;
  static const _lon0 = 125.7;
  static const _kx = 110582.25626663613;
  static const _ky = 110574.0;
  static const _cell = 30.0;

  static List<GulfCoastalMunicipality> _zones = const [];
  static List<GulfCoastalBarangay> _parts = const [];
  static Map<String, GulfCoastalBarangay> _byCode = const {};
  static Int32List _runs = Int32List(0);
  static List<dynamic> _outlineJson = const [];
  static final Map<int, List<List<LatLng>>> _ringCache = {};
  static bool _loaded = false;

  static bool get isLoaded => _loaded;

  /// Loads the map files bundled with the app. Call once before use.
  static Future<void> load([AssetBundle? bundle]) async {
    if (_loaded) return;
    final b = bundle ?? rootBundle;
    final parts = await b.loadString('assets/map/parts.json');
    final areas = await b.loadString('assets/map/areas.json');
    final outlines = await b.loadString('assets/map/part_outlines.json');
    final lookup = await b.load('assets/map/lookup.bin');
    loadFromData(
      partsJson: parts,
      areasJson: areas,
      outlinesJson: outlines,
      lookup: lookup.buffer.asUint8List(lookup.offsetInBytes, lookup.lengthInBytes),
    );
  }

  /// Loads the map from raw file contents (used by [load] and by tests).
  static void loadFromData({
    required String partsJson,
    required String areasJson,
    required String outlinesJson,
    required Uint8List lookup,
  }) {
    final meta = jsonDecode(partsJson) as Map<String, dynamic>;
    final zoneRows = (meta['zones'] as List).cast<Map<String, dynamic>>();
    final partRows = (meta['parts'] as List).cast<List<dynamic>>();
    final parts = <GulfCoastalBarangay>[];
    for (var i = 0; i < partRows.length; i++) {
      final r = partRows[i];
      final zone = zoneRows[(r[7] as num).toInt()];
      parts.add(GulfCoastalBarangay._(
        index: i,
        id: r[0] as String,
        areaCode: r[1] as String,
        name: r[2] as String,
        partNo: (r[3] as num).toInt(),
        reefHectares: (r[4] as num).toDouble(),
        centroid: LatLng((r[5] as num).toDouble(), (r[6] as num).toDouble()),
        zoneCode: zone['code'] as String,
        municipalityId: (zone['code'] as String).toLowerCase(),
        municipalityName: zone['town'] as String,
        psgc: r.length > 8 ? '${r[8]}' : '',
      ));
    }
    final partsByArea = <String, List<GulfCoastalBarangay>>{};
    for (final p in parts) {
      (partsByArea[p.areaCode] ??= []).add(p);
    }
    final areasByZone = <String, List<GulfMonitoringArea>>{};
    for (final a in (jsonDecode(areasJson) as List).cast<Map<String, dynamic>>()) {
      final rings = [for (final r in (a['rings'] as List)) _ring(r as List)];
      final areaParts = partsByArea[a['code']] ?? const <GulfCoastalBarangay>[];
      final area = GulfMonitoringArea._(
        code: a['code'] as String,
        zoneCode: a['zone'] as String,
        barangay: a['barangay'] as String,
        rings: rings,
        parts: areaParts,
        centroid: _centre(rings.isEmpty ? const [] : rings.first),
      );
      (areasByZone[area.zoneCode] ??= []).add(area);
    }
    final zones = <GulfCoastalMunicipality>[];
    for (final z in zoneRows) {
      final code = z['code'] as String;
      final c = (z['centre'] as List).cast<num>();
      zones.add(GulfCoastalMunicipality._(
        id: code.toLowerCase(),
        zoneCode: code,
        name: z['town'] as String,
        centroid: LatLng(c[0].toDouble(), c[1].toDouble()),
        boundary: _ring(z['hull'] as List),
        areas: areasByZone[code] ?? const [],
        barangays: [for (final p in parts) if (p.zoneCode == code) p],
      ));
    }
    _zones = zones;
    _parts = parts;
    _byCode = {for (final p in parts) p.id: p};
    _outlineJson = jsonDecode(outlinesJson) as List;
    _ringCache.clear();
    final bytes = ByteData.sublistView(lookup);
    final runs = Int32List(lookup.lengthInBytes ~/ 4);
    for (var i = 0; i < runs.length; i++) {
      runs[i] = bytes.getInt32(i * 4, Endian.little);
    }
    _runs = runs;
    _loaded = true;
  }

  static List<LatLng> _ring(List flat) => [
        for (var i = 0; i + 1 < flat.length; i += 2)
          LatLng((flat[i] as num).toDouble(), (flat[i + 1] as num).toDouble()),
      ];

  static LatLng _centre(List<LatLng> ring) {
    if (ring.isEmpty) return const LatLng(_lat0, _lon0);
    var lat = 0.0, lng = 0.0;
    for (final p in ring) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / ring.length, lng / ring.length);
  }

  static List<List<LatLng>> _partRings(int index) {
    return _ringCache.putIfAbsent(index, () {
      if (index >= _outlineJson.length) return const [];
      final rings = [for (final r in (_outlineJson[index] as List)) _ring(r as List)];
      rings.sort((a, b) => b.length.compareTo(a.length));
      return rings;
    });
  }

  static List<GulfCoastalMunicipality> get municipalities => _zones;
  static List<GulfCoastalBarangay> get allBarangays => _parts;

  /// One entry per area (its first part), e.g. for overview markers.
  static List<GulfCoastalBarangay> get areaRepresentatives => [
        for (final z in _zones)
          for (final a in z.areas)
            if (a.parts.isNotEmpty) a.parts.first,
      ];

  static GulfCoastalMunicipality? municipalityByZoneCode(String zoneCode) {
    for (final m in _zones) {
      if (m.zoneCode == zoneCode) return m;
    }
    return null;
  }

  static GulfCoastalMunicipality? municipalityById(String id) {
    for (final m in _zones) {
      if (m.id == id) return m;
    }
    return null;
  }

  static GulfCoastalBarangay? barangayById(String id) => _byCode[id];

  static List<LatLng> boundsPointsFor(GulfCoastalMunicipality municipality) =>
      municipality.boundary;

  /// Centre and zoom used when opening Zone A on the map.
  static const LatLng panaboMarineSectorCenter = LatLng(7.285, 125.70);
  static const double panaboMarineSectorZoom = 13.2;

  /// The part at a location: inside it, or the nearest part within 15 m.
  /// Returns null when the location is on land or in deep water.
  static GulfCoastalBarangay? partAt(
    double latitude,
    double longitude, {
    double allowanceMeters = allowanceMeters,
  }) {
    if (!_loaded || !latitude.isFinite || !longitude.isFinite) return null;
    final gx = (longitude - _lon0) * _kx / _cell;
    final gy = (latitude - _lat0) * _ky / _cell;
    final ix = gx.round();
    final iy = gy.round();
    GulfCoastalBarangay? best;
    var bestMeters = double.infinity;
    for (var row = iy - 1; row <= iy + 1; row++) {
      var i = _firstRunAtOrAfter(row);
      while (i < _runs.length ~/ 4 && _runs[i * 4] == row) {
        final start = _runs[i * 4 + 1];
        final end = _runs[i * 4 + 2];
        if (start <= ix + 1 && end >= ix - 1) {
          final cx = math.max(start, math.min(end, ix));
          final dx = math.max((gx - cx).abs() - 0.5, 0.0);
          final dy = math.max((gy - row).abs() - 0.5, 0.0);
          final meters = _cell * math.sqrt(dx * dx + dy * dy);
          final part = _parts[_runs[i * 4 + 3]];
          if (meters <= allowanceMeters &&
              (meters < bestMeters ||
                  (meters == bestMeters && best != null && part.id.compareTo(best.id) < 0))) {
            bestMeters = meters;
            best = part;
          }
        }
        if (start > ix + 1) break;
        i++;
      }
    }
    return best;
  }

  /// A location surely inside [part] (the centre of one of its grid cells).
  static LatLng? pointInside(GulfCoastalBarangay part) {
    for (var i = 0; i < _runs.length ~/ 4; i++) {
      if (_runs[i * 4 + 3] != part.index) continue;
      final row = _runs[i * 4];
      final col = (_runs[i * 4 + 1] + _runs[i * 4 + 2]) ~/ 2;
      return LatLng(row * _cell / _ky + _lat0, col * _cell / _kx + _lon0);
    }
    return null;
  }

  /// Index of the first run in [row] (binary search over the sorted runs).
  static int _firstRunAtOrAfter(int row) {
    var lo = 0, hi = _runs.length ~/ 4;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_runs[mid * 4] < row) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  static GulfZoneAssignment? _assignment(GulfCoastalBarangay? part) {
    if (part == null) return null;
    final zone = municipalityByZoneCode(part.zoneCode);
    if (zone == null) return null;
    return GulfZoneAssignment(
      municipality: zone,
      barangay: part,
      zoneLabel: '${part.zoneLabel} · ${part.id}',
    );
  }

  /// The monitoring part at a location (inside, or within 15 m). Null when the
  /// location is on land or in deep water. Same rule as the database.
  static GulfZoneAssignment? assignWithinMonitoringArea({
    double? latitude,
    double? longitude,
  }) {
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return _assignment(partAt(latitude, longitude));
  }

  /// Like [assignWithinMonitoringArea], but for labels only: when the
  /// location is in no part, falls back to the nearest part within 12 km.
  static GulfZoneAssignment? assign({double? latitude, double? longitude}) {
    final exact = assignWithinMonitoringArea(
      latitude: latitude,
      longitude: longitude,
    );
    if (exact != null || latitude == null || longitude == null) return exact;
    const distance = Distance();
    final point = LatLng(latitude, longitude);
    GulfCoastalBarangay? nearest;
    var bestMeters = double.infinity;
    for (final p in _parts) {
      final m = distance.as(LengthUnit.Meter, point, p.centroid);
      if (m < bestMeters) {
        bestMeters = m;
        nearest = p;
      }
    }
    if (nearest == null || bestMeters > 12000) return null;
    final a = _assignment(nearest);
    if (a == null) return null;
    return GulfZoneAssignment(
      municipality: a.municipality,
      barangay: a.barangay,
      zoneLabel: 'Near ${a.barangay.id}',
    );
  }
}
