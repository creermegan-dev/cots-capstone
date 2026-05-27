import 'package:latlong2/latlong.dart';

import '../features/user/cots_map_page.dart';

/// Assigns the nearest monitoring zone from sample GIS zones.
abstract final class ZoneAssignmentService {
  static const _distance = Distance();

  static String assignZone({double? latitude, double? longitude}) {
    if (latitude == null || longitude == null) return 'Unassigned';
    final point = LatLng(latitude, longitude);
    CotsZone? nearest;
    var bestMeters = double.infinity;
    for (final zone in kSampleZones) {
      final meters = _distance.as(
        LengthUnit.Meter,
        point,
        zone.position,
      );
      if (meters < bestMeters) {
        bestMeters = meters;
        nearest = zone;
      }
    }
    if (nearest == null) return 'Unassigned';
    // Treat zones within ~8 km as a match (demo reef scale).
    if (bestMeters > 8000) return 'Unassigned';
    return nearest.label;
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
