import '../models/davao_gulf_geography.dart';

/// Assigns monitoring areas from Davao Gulf coastal municipality / barangay GIS data.
abstract final class ZoneAssignmentService {
  static String assignZone({double? latitude, double? longitude}) {
    final assignment = resolveArea(
      latitude: latitude,
      longitude: longitude,
    );
    return assignment?.zoneLabel ?? 'Unassigned';
  }

  static GulfZoneAssignment? resolveArea({
    double? latitude,
    double? longitude,
  }) {
    return DavaoGulfGeography.assign(
      latitude: latitude,
      longitude: longitude,
    );
  }

  static String formatCoordinates(double? lat, double? lng) {
    if (lat == null || lng == null) return '--';
    final latStr =
        '${lat.abs().toStringAsFixed(6)}° ${lat >= 0 ? 'N' : 'S'}';
    final lngStr =
        '${lng.abs().toStringAsFixed(6)}° ${lng >= 0 ? 'E' : 'W'}';
    return '$latStr, $lngStr';
  }
}
