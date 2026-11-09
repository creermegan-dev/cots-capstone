/// Citizen science activity classification for a GoPro submission.
abstract final class CotsActivityType {
  static const detectionOnly = 'detection_only';
  static const removalActivity = 'removal_activity';
  static const followUpSurvey = 'follow_up_survey';

  static const labels = {
    detectionOnly: 'Detection Only',
    removalActivity: 'Removal Activity',
    followUpSurvey: 'Follow-up Survey',
  };

  static String label(String value) => labels[value] ?? value;

  static bool isRemoval(String value) => value == removalActivity;
}

abstract final class CaptureSource {
  static const goProUnderwaterImage = 'GoPro Underwater Image';

  /// Legacy source values were defaults, not camera metadata. Never present
  /// those defaults as evidence of which camera took the photo.
  static String displayLabel(String source) {
    final value = source.trim();
    return switch (value.toLowerCase()) {
      'per photo' => 'Per photo',
      '' ||
      'unknown' ||
      'unknown device' ||
      'not recorded' ||
      'gopro underwater image' ||
      'gopro image' ||
      'gopro' ||
      'camera' ||
      'photo' ||
      'image' =>
        'Photo — camera not recorded',
      'gallery' || 'gallery upload' => 'Photo from gallery',
      _ => value,
    };
  }
}

abstract final class RemovalMethod {
  static const manual = 'Manual Removal';
  static const vinegar = 'Vinegar Injection';
  static const oxBile = 'Ox Bile / Bile Salts Injection';

  /// Older records only; no longer offered (Stage 5). Old records keep them.
  static const communityCleanup = 'Community Cleanup';
  static const researchCollection = 'Research Collection';

  /// Older records only; no longer offered (use vinegar or ox bile instead).
  static const injection = 'Injection Method';

  /// Methods a Diver can choose for new records (Stage 5, agreed): manual
  /// removal, vinegar injection and ox bile injection. Old records keep
  /// whatever method they already store.
  static const options = [
    manual,
    vinegar,
    oxBile,
  ];

  /// Injections need up to 2 days to kill COTS. The database decides the
  /// early-visit flag and excused months from the stored method (Stage 5).
  static bool isInjection(String method) =>
      method == vinegar || method == oxBile || method == injection;
}
