/// Firestore collection names for citizen science records.
abstract final class RecordCollection {
  static const captures = 'captures';
  static const captureImages = 'capture_images';
  static const removalRecords = 'removal_records';
  static const removalRecordImages = 'removal_record_images';
  static const followUpSurveys = 'follow_up_surveys';
  static const interventionAssignments = 'intervention_assignments';
  static const notifications = 'notifications';

  /// Legacy — read-only for older submissions.
  static const legacyScanRecords = 'scan_records';
  static const legacyScanRecordImages = 'scan_record_images';
}
