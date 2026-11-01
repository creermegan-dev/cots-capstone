/// Where a photo's location and time came from. The app saves this with each
/// photo; the details pages show it so the Expert can judge how reliable the
/// location and time are (claude/agreed_workflow_decisions.md).
abstract final class PhotoSource {
  /// Stored location codes (`gps_source` in Supabase) as shown to people.
  static String locationLabel(String code) => switch (code) {
        'exif' => 'Photo GPS',
        'device_surface' => 'Phone GPS (at the surface)',
        'manual_surface' => 'Typed in',
        'unavailable' => 'Not available',
        _ => 'Not recorded',
      };

  /// Stored time codes (`capture_time_source`): where the date taken came
  /// from. Empty when not recorded (older and Firebase records).
  static String timeNote(String code) => switch (code) {
        'exif' => 'from photo',
        'device' => 'from phone clock',
        'manual' => 'entered by Diver',
        _ => '',
      };

  /// "Oct 31, 2026 9:40 AM (from photo)"; the date alone when not recorded.
  static String dateTaken(String formatted, String code) {
    final note = timeNote(code);
    return note.isEmpty || formatted == 'Unknown' ? formatted : '$formatted ($note)';
  }
}
