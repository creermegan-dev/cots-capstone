/// Explicit Expert-validated metadata. Counts never imply an assessment.
class FollowUpInfestationAssessment {
  const FollowUpInfestationAssessment(
      this.level, this.validatedBy, this.validatedAt, this.surveyDate);
  final String level;
  final String validatedBy;
  final DateTime validatedAt;
  final DateTime surveyDate;
  bool get isHigh => level == 'High';
  static FollowUpInfestationAssessment? fromMap(Map<String, dynamic> data) {
    final level = data['validated_infestation_level'];
    final by = data['infestation_validated_by'];
    final at = data['infestation_validated_at'];
    final date = data['survey_date'];
    if (!['Low', 'Moderate', 'High'].contains(level) ||
        by is! String ||
        by.isEmpty ||
        at is! DateTime ||
        date is! DateTime) {
      return null;
    }
    return FollowUpInfestationAssessment(level as String, by, at, date);
  }
}
