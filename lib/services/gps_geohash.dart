import 'package:latlong2/latlong.dart';

/// Clean, high-performance local Base32 Geohashing implementation.
///
/// Avoids external package bloat and supports strict offline boundary calculation.
abstract final class GpsGeohash {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Encodes [latitude] and [longitude] to a geohash string with specified [precision].
  static String encode(double latitude, double longitude, {int precision = 9}) {
    double minLat = -90.0, maxLat = 90.0;
    double minLng = -180.0, maxLng = 180.0;

    final geohash = StringBuffer();
    bool isEven = true;
    int bit = 0;
    int ch = 0;

    while (geohash.length < precision) {
      if (isEven) {
        final mid = (minLng + maxLng) / 2;
        if (longitude >= mid) {
          ch = (ch << 1) | 1;
          minLng = mid;
        } else {
          ch = (ch << 1) | 0;
          maxLng = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (latitude >= mid) {
          ch = (ch << 1) | 1;
          minLat = mid;
        } else {
          ch = (ch << 1) | 0;
          maxLat = mid;
        }
      }

      isEven = !isEven;
      if (bit < 4) {
        bit++;
      } else {
        geohash.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return geohash.toString();
  }

  /// Calculates the geohash range prefixes for a bounding box defined by [southWest] and [northEast].
  /// Returns a list of start/end query ranges suited for Firestore single-inequality filters:
  /// `geohash >= range.start && geohash <= range.end`
  static List<(String, String)> queryRanges(LatLng southWest, LatLng northEast, {int precision = 5}) {
    final swHash = encode(southWest.latitude, southWest.longitude, precision: precision);
    final neHash = encode(northEast.latitude, northEast.longitude, precision: precision);

    if (swHash == neHash) {
      return [(swHash, '$swHash~')];
    }

    // Sort prefixes lexicographically to construct a bounded range
    final sorted = [swHash, neHash]..sort();
    return [(sorted[0], '${sorted[1]}~')];
  }
}
