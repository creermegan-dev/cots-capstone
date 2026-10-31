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
}

abstract final class RemovalMethod {
  static const manual = 'Manual Removal';
  static const vinegar = 'Vinegar Injection';
  static const oxBile = 'Ox Bile / Bile Salts Injection';
  static const communityCleanup = 'Community Cleanup';
  static const researchCollection = 'Research Collection';

  /// Older records only; no longer offered (use vinegar or ox bile instead).
  static const injection = 'Injection Method';

  /// Methods a Diver can choose for new records. "Community Cleanup" and
  /// "Research Collection" will be removed later (agreed); old records keep
  /// whatever method they already store.
  static const options = [
    manual,
    vinegar,
    oxBile,
    communityCleanup,
    researchCollection,
  ];

  /// Injections need 1-2 days to kill COTS (used by the later follow-up
  /// reminder stage).
  static bool isInjection(String method) =>
      method == vinegar || method == oxBile || method == injection;
}
