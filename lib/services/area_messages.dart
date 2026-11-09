import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/davao_gulf_geography.dart';

/// Plain-language messages for the site checks (Stages 6, 7 and 9).
///
/// The database refuses a record whose GPS is outside its site (allowing
/// 15 m for GPS error) with a message starting `COTS_AREA_...`; this turns
/// those into sentences a Diver understands.
abstract final class AreaMessages {
  static const outside =
      'This location is outside every dive site (on land or past the '
      'drop-off). Records must be made at Site 1 · Tambo, Site 2 · Adecor or '
      'Site 3 · Linosutan, in the water.';
  static const noLocation =
      'A location is required. Turn on location, or use a photo that has GPS.';
  static const inactive =
      'This site is no longer used. Please update the app.';

  /// The site's name for a code such as `S2` (falls back to the code).
  static String siteName(String code) =>
      DavaoGulfGeography.barangayById(code)?.displayName ?? code;

  static String otherPart(String code) {
    final name = siteName(code);
    return 'Some photos were taken in $name. '
        'Please submit them as a separate record for $name.';
  }

  static final _pattern =
      RegExp(r'COTS_AREA_(OUTSIDE|MISMATCH|INACTIVE|NO_LOCATION)(?::([A-Z]\d+(?:-\d+)?))?');

  /// The message for a site-check refusal, or null for any other error.
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
