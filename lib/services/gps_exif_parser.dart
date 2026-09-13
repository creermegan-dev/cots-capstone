import 'package:exif/exif.dart';

/// Parses GPS coordinates from image EXIF tags.
abstract final class GpsExifParser {
  static (double, double)? parse(Map<String, IfdTag> exif) {
    final latTag = exif['GPS GPSLatitude'];
    final lngTag = exif['GPS GPSLongitude'];
    if (latTag == null || lngTag == null) return null;
    final lat = _dmsToDecimal(latTag.values.toList());
    final lng = _dmsToDecimal(lngTag.values.toList());
    if (lat == null || lng == null) return null;
    final latRef = exif['GPS GPSLatitudeRef']?.printable;
    final lngRef = exif['GPS GPSLongitudeRef']?.printable;
    return (latRef == 'S' ? -lat : lat, lngRef == 'W' ? -lng : lng);
  }

  static double? _dmsToDecimal(List<dynamic> parts) {
    if (parts.length < 3) return null;
    double value(dynamic v) {
      if (v is Ratio) return v.numerator / v.denominator;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }
    return value(parts[0]) + (value(parts[1]) / 60) + (value(parts[2]) / 3600);
  }
}
