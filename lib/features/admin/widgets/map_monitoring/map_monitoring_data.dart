import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

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
        return 'High';
      case MapMonitoringRisk.moderate:
        return 'Moderate';
      case MapMonitoringRisk.low:
        return 'Low';
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
    this.cotsDetected = 0,
    this.cotsRemoved = 0,
    this.averageSizeCm,
  });

  final String code;
  final String displayName;
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
      'Real-time monitoring of COTS density across all zones.';
  static const String lastUpdated = 'May 18, 2026 · 09:30 AM';

  static const densityOverview = (
    high: 4,
    moderate: 2,
    low: 5,
    noData: 1,
  );

  static const summary = (
    totalZones: 12,
    activeHighRisk: 4,
    avgDensity: 32.45,
    totalCotsDetected: 248,
  );

  /// Coastal Philippines — mock patrol areas.
  static final zones = <MonitoringZone>[
    MonitoringZone(
      code: 'A',
      displayName: 'Zone A',
      risk: MapMonitoringRisk.high,
      densityCotsPerHa: 78.4,
      statusLabel: 'Active (Outbreak)',
      lastMonitoring: 'May 18, 2026 · 09:12',
      outbreakStatus: 'Active',
      cotsDetected: 78,
      cotsRemoved: 35,
      averageSizeCm: 38,
      polygon: const [
        LatLng(7.14, 125.58),
        LatLng(7.20, 125.64),
        LatLng(7.16, 125.74),
        LatLng(7.08, 125.68),
      ],
    ),
    MonitoringZone(
      code: 'B',
      displayName: 'Zone B',
      risk: MapMonitoringRisk.high,
      densityCotsPerHa: 55.2,
      statusLabel: 'Active (Outbreak)',
      lastMonitoring: 'May 18, 2026 · 08:55',
      outbreakStatus: 'Active',
      polygon: const [
        LatLng(7.22, 125.68),
        LatLng(7.28, 125.72),
        LatLng(7.26, 125.82),
        LatLng(7.18, 125.78),
      ],
    ),
    MonitoringZone(
      code: 'C',
      displayName: 'Zone C',
      risk: MapMonitoringRisk.moderate,
      densityCotsPerHa: 47.1,
      statusLabel: 'Scheduled sweep',
      lastMonitoring: 'May 17, 2026 · 16:40',
      outbreakStatus: 'Scheduled',
      polygon: const [
        LatLng(7.02, 125.62),
        LatLng(7.08, 125.58),
        LatLng(7.10, 125.70),
        LatLng(7.04, 125.74),
      ],
    ),
    MonitoringZone(
      code: 'D',
      displayName: 'Zone D',
      risk: MapMonitoringRisk.low,
      densityCotsPerHa: 30.2,
      statusLabel: 'Monitoring',
      lastMonitoring: 'May 17, 2026 · 14:22',
      outbreakStatus: 'Stable',
      polygon: const [
        LatLng(6.96, 125.70),
        LatLng(7.02, 125.66),
        LatLng(7.04, 125.78),
        LatLng(6.98, 125.82),
      ],
    ),
    MonitoringZone(
      code: 'E',
      displayName: 'Zone E',
      risk: MapMonitoringRisk.low,
      densityCotsPerHa: 62.0,
      statusLabel: 'Monitoring',
      lastMonitoring: 'May 18, 2026 · 07:05',
      outbreakStatus: 'Stable',
      polygon: const [
        LatLng(7.08, 125.82),
        LatLng(7.14, 125.78),
        LatLng(7.12, 125.90),
        LatLng(7.02, 125.88),
      ],
    ),
    MonitoringZone(
      code: 'F',
      displayName: 'Zone F',
      risk: MapMonitoringRisk.moderate,
      densityCotsPerHa: 22.6,
      statusLabel: 'Elevated watch',
      lastMonitoring: 'May 16, 2026 · 11:18',
      outbreakStatus: 'Watch',
      polygon: const [
        LatLng(7.28, 125.52),
        LatLng(7.34, 125.56),
        LatLng(7.32, 125.66),
        LatLng(7.24, 125.62),
      ],
    ),
  ];

  static final highRiskRows = <HighRiskTableRow>[
    const HighRiskTableRow(
      zoneName: 'Zone A — Northern Reef',
      avgDensity: 78.4,
      risk: MapMonitoringRisk.high,
      status: 'Active (Outbreak)',
      lastMonitoring: 'May 18, 2026 · 09:12',
    ),
    const HighRiskTableRow(
      zoneName: 'Zone B — East Shoal',
      avgDensity: 55.2,
      risk: MapMonitoringRisk.high,
      status: 'Active (Outbreak)',
      lastMonitoring: 'May 18, 2026 · 08:55',
    ),
    const HighRiskTableRow(
      zoneName: 'Zone H — Survey pending',
      avgDensity: 41.8,
      risk: MapMonitoringRisk.moderate,
      status: 'Scheduled',
      lastMonitoring: 'May 17, 2026 · 15:00',
    ),
  ];

  static const alerts = <MapAlertItem>[
    MapAlertItem(
      zoneName: 'Zone A',
      message: 'Density spike · 78.4 COTS/ha — exceeds outbreak threshold',
      timeAgo: '10 min ago',
    ),
    MapAlertItem(
      zoneName: 'Zone B',
      message: 'New aggregation cluster detected near transect B-4',
      timeAgo: '42 min ago',
    ),
    MapAlertItem(
      zoneName: 'Zone C',
      message: 'Sweep team dispatched — ETA 14:30',
      timeAgo: '2 hr ago',
    ),
  ];
}
