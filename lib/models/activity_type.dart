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
  static const injection = 'Injection Method';
  static const communityCleanup = 'Community Cleanup';
  static const researchCollection = 'Research Collection';

  static const options = [
    manual,
    injection,
    communityCleanup,
    researchCollection,
  ];
}
