import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'davao_gulf_geography.dart';

const Color _kHigh = Color(0xFFE53935);
const Color _kModerate = Color(0xFFFFA726);
const Color _kLow = Color(0xFF43A047);

enum OutbreakLevel { high, moderate, low }

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

  /// Builds a map/detail card from a dive site.
  factory CotsZone.fromCoastalBarangay(GulfCoastalBarangay barangay) {
    final hash = barangay.id.hashCode.abs();
    final level = switch (hash % 3) {
      0 => OutbreakLevel.high,
      1 => OutbreakLevel.moderate,
      _ => OutbreakLevel.low,
    };
    final density = switch (level) {
      OutbreakLevel.high => 18.0 + (hash % 120) / 10,
      OutbreakLevel.moderate => 6.0 + (hash % 80) / 10,
      OutbreakLevel.low => 1.5 + (hash % 30) / 10,
    };
    final status = switch (level) {
      OutbreakLevel.high => 'Active',
      OutbreakLevel.moderate => 'Scheduled',
      OutbreakLevel.low => 'Cleared',
    };
    final lat = barangay.centroid.latitude;
    final lng = barangay.centroid.longitude;
    final coords =
        '${lat.abs().toStringAsFixed(4)}° ${lat >= 0 ? 'N' : 'S'}, '
        '${lng.abs().toStringAsFixed(4)}° ${lng >= 0 ? 'E' : 'W'}';
    return CotsZone(
      id: barangay.id,
      label: barangay.areaCode,
      name: barangay.displayName,
      position: barangay.centroid,
      level: level,
      density: density,
      status: status,
      totalScans: 2 + hash % 12,
      avgDensity: density * 0.85,
      lastScan: 'Monitoring active',
      cotsDetected: hash % 40,
      location: coords,
      radius: '100 m² survey unit',
      reason: barangay.beachNote ??
          'Dive site in ${barangay.name}, Samal.',
      dateCreated: 'Samal dive sites map',
      statusHistory: [
        StatusHistoryItem(
          date: '—',
          time: '—',
          statusLabel: status,
          detail: barangay.subtitle,
          isCurrent: true,
          level: level,
        ),
      ],
    );
  }
}

/// Sample map cards, one per dive site. The map page
/// still shows generated sample levels until Stage 8 brings real data.
List<CotsZone>? _sampleZonesCache;
List<CotsZone> get kSampleZones => _sampleZonesCache ??= DavaoGulfGeography
    .areaRepresentatives
    .map(CotsZone.fromCoastalBarangay)
    .toList(growable: false);

Color outbreakColor(OutbreakLevel level) {
  switch (level) {
    case OutbreakLevel.high:
      return _kHigh;
    case OutbreakLevel.moderate:
      return _kModerate;
    case OutbreakLevel.low:
      return _kLow;
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
