import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../models/cots_zone.dart';
import '../../../../models/davao_gulf_geography.dart';
import '../../theme/admin_theme.dart';

enum MapMonitoringRisk { high, moderate, low }

enum MapMonitoringViewMode { mapViewing, heatMap, densityLayers }

extension MapMonitoringRiskX on MapMonitoringRisk {
  Color get color {
    switch (this) {
      case MapMonitoringRisk.high:
        return AdminColors.statRed;
      case MapMonitoringRisk.moderate:
        return AdminColors.statYellow;
      case MapMonitoringRisk.low:
        return AdminColors.statGreen;
    }
  }

  String get label {
    switch (this) {
      case MapMonitoringRisk.high:
        return 'High infestation';
      case MapMonitoringRisk.moderate:
        return 'Moderate infestation';
      case MapMonitoringRisk.low:
        return 'Low infestation';
    }
  }
}

/// Single monitoring zone with polygon corners (mock GIS data).
class MonitoringZone {
  const MonitoringZone({
    required this.code,
    required this.displayName,
    required this.polygon,
    required this.risk,
    required this.densityCotsPerHa,
    required this.statusLabel,
    required this.lastMonitoring,
    required this.outbreakStatus,
    this.fullName,
    this.zoneCode,
    this.isMunicipality = false,
    this.cotsDetected = 0,
    this.cotsRemoved = 0,
    this.averageSizeCm,
  });

  final String code;
  final String displayName;
  final String? fullName;
  final String? zoneCode;
  final bool isMunicipality;
  final List<LatLng> polygon;
  final MapMonitoringRisk risk;
  final double densityCotsPerHa;
  final String statusLabel;
  final String lastMonitoring;
  final String outbreakStatus;
  final int cotsDetected;
  final int cotsRemoved;
  final double? averageSizeCm;

  LatLng get centroid {
    double lat = 0, lng = 0;
    for (final p in polygon) {
      lat += p.latitude;
      lng += p.longitude;
    }
    final n = polygon.length.toDouble();
    return LatLng(lat / n, lng / n);
  }
}

class HighRiskTableRow {
  const HighRiskTableRow({
    required this.zoneName,
    required this.avgDensity,
    required this.risk,
    required this.status,
    required this.lastMonitoring,
  });

  final String zoneName;
  final double avgDensity;
  final MapMonitoringRisk risk;
  final String status;
  final String lastMonitoring;
}

class MapAlertItem {
  const MapAlertItem({
    required this.zoneName,
    required this.message,
    required this.timeAgo,
  });

  final String zoneName;
  final String message;
  final String timeAgo;
}

abstract final class MapMonitoringMock {
  static const String subtitle =
      'Davao Gulf coastal zones — tap a zone to view barangay sites.';
  static const String lastUpdated = 'Live GIS · Davao Gulf';

  static MapMonitoringRisk _riskFromLevel(OutbreakLevel level) {
    return switch (level) {
      OutbreakLevel.high => MapMonitoringRisk.high,
      OutbreakLevel.moderate => MapMonitoringRisk.moderate,
      OutbreakLevel.low => MapMonitoringRisk.low,
    };
  }

  static MonitoringZone _fromBarangay(GulfCoastalBarangay b) {
    final card = CotsZone.fromCoastalBarangay(b);
    final risk = _riskFromLevel(card.level);
    return MonitoringZone(
      code: b.siteCode,
      displayName: b.siteCode,
      fullName: b.name,
      zoneCode: b.zoneCode,
      polygon: b.polygon,
      risk: risk,
      densityCotsPerHa: card.density,
      statusLabel: b.subtitle,
      lastMonitoring: 'Active monitoring',
      outbreakStatus: card.status,
      cotsDetected: card.cotsDetected,
      cotsRemoved: card.cotsDetected ~/ 3,
      averageSizeCm: 24 + b.id.hashCode.abs() % 18,
    );
  }

  static MonitoringZone _fromMunicipality(GulfCoastalMunicipality m) {
    final sites = m.barangays.map(_fromBarangay).toList(growable: false);
    final avgDensity = sites.isEmpty
        ? 0.0
        : sites.map((s) => s.densityCotsPerHa).reduce((a, b) => a + b) /
            sites.length;
    final risk = sites.isEmpty
        ? MapMonitoringRisk.low
        : sites.map((s) => s.risk).reduce(_maxRisk);
    final detected = sites.fold<int>(0, (sum, s) => sum + s.cotsDetected);
    return MonitoringZone(
      code: m.zoneCode,
      displayName: m.zoneLabel,
      fullName: m.name,
      zoneCode: m.zoneCode,
      isMunicipality: true,
      polygon: m.boundary,
      risk: risk,
      densityCotsPerHa: avgDensity,
      statusLabel: '${m.barangayCount} coastal sites',
      lastMonitoring: m.province,
      outbreakStatus: 'Zone overview',
      cotsDetected: detected,
      cotsRemoved: detected ~/ 3,
    );
  }

  static MapMonitoringRisk _maxRisk(
    MapMonitoringRisk a,
    MapMonitoringRisk b,
  ) {
    const order = {
      MapMonitoringRisk.high: 3,
      MapMonitoringRisk.moderate: 2,
      MapMonitoringRisk.low: 1,
    };
    return (order[a] ?? 0) >= (order[b] ?? 0) ? a : b;
  }

  static List<MonitoringZone> get barangays {
    return DavaoGulfGeography.allBarangays
        .map(_fromBarangay)
        .toList(growable: false);
  }

  /// Municipality-level zones (Zone A–Q) for map overview.
  static List<MonitoringZone> get zones {
    return DavaoGulfGeography.municipalities
        .map(_fromMunicipality)
        .toList(growable: false);
  }

  static List<MonitoringZone> barangaysForZone(String zoneCode) {
    final municipality = DavaoGulfGeography.municipalityByZoneCode(zoneCode);
    if (municipality == null) return const [];
    return municipality.barangays.map(_fromBarangay).toList(growable: false);
  }

  static int get _highCount =>
      barangays.where((z) => z.risk == MapMonitoringRisk.high).length;
  static int get _moderateCount =>
      barangays.where((z) => z.risk == MapMonitoringRisk.moderate).length;
  static int get _lowCount =>
      barangays.where((z) => z.risk == MapMonitoringRisk.low).length;

  static ({int high, int moderate, int low, int noData}) get densityOverview => (
        high: _highCount,
        moderate: _moderateCount,
        low: _lowCount,
        noData: 0,
      );

  static ({int totalZones, int activeHighRisk, double avgDensity, int totalCotsDetected})
      get summary => (
        totalZones: zones.length,
        activeHighRisk: _highCount,
        avgDensity: barangays.isEmpty
            ? 0
            : barangays.map((z) => z.densityCotsPerHa).reduce((a, b) => a + b) /
                barangays.length,
        totalCotsDetected:
            barangays.fold<int>(0, (sum, z) => sum + z.cotsDetected),
      );

  static List<HighRiskTableRow> get highRiskRows {
    final high = barangays.where((z) => z.risk == MapMonitoringRisk.high).take(3);
    return high
        .map(
          (z) => HighRiskTableRow(
            zoneName: z.fullName ?? z.displayName,
            avgDensity: z.densityCotsPerHa,
            risk: z.risk,
            status: z.statusLabel,
            lastMonitoring: z.lastMonitoring,
          ),
        )
        .toList(growable: false);
  }

  static List<MapAlertItem> get alerts {
    final high = barangays.where((z) => z.risk == MapMonitoringRisk.high).take(3);
    return high
        .map(
          (z) => MapAlertItem(
            zoneName: '${z.displayName} · ${z.fullName ?? z.displayName}',
            message:
                'Elevated density · ${z.densityCotsPerHa.toStringAsFixed(1)} COTS/ha',
            timeAgo: 'Recent scan activity',
          ),
        )
        .toList(growable: false);
  }
}
