import 'package:supabase_flutter/supabase_flutter.dart';

/// Plain-language messages for the monitoring-area checks (Stage 6).
///
/// The database refuses a record whose GPS is outside its part (allowing
/// 15 m for GPS error) with a message starting `COTS_AREA_...`; this turns
/// those into sentences a Diver understands.
abstract final class AreaMessages {
  static const outside =
      'This location is outside every monitoring area (on land or in deep '
      'water). Records must be made at the dive site, in the water.';
  static const noLocation =
      'A location is required. Turn on location, or use a photo that has GPS.';
  static const inactive =
      'This monitoring area is no longer used. Please update the app.';

  static String otherPart(String code) =>
      'Some photos were taken in area $code. '
      'Please submit them as a separate record for $code.';

  static final _pattern =
      RegExp(r'COTS_AREA_(OUTSIDE|MISMATCH|INACTIVE|NO_LOCATION)(?::([A-Z]\d+(?:-\d+)?))?');

  /// The message for an area-check refusal, or null for any other error.
  static String? forError(Object error) {
    final text = error is PostgrestException ? error.message : error.toString();
    final match = _pattern.firstMatch(text);
    if (match == null) return null;
    switch (match.group(1)) {
      case 'OUTSIDE':
        return outside;
      case 'INACTIVE':
        return inactive;
      case 'NO_LOCATION':
        return noLocation;
      default:
        final code = match.group(2);
        return code == null ? outside : otherPart(code);
    }
  }
}
