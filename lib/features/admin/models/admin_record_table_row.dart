/// Row model for the Records / Submissions table (shared with details navigation).
///
/// Verification follows AI confidence bands:
/// - **Verified** (AI): confidence ≥ 85%
/// - **Needs Review**: 60% ≤ confidence ≤ 84% — admin must confirm or reject
/// - **Rejected**: confidence < 60% (60% is *not* rejected; it stays in Needs Review), or **admin rejected** from review
class AdminRecordTableRow {
  const AdminRecordTableRow(
    this.number,
    this.recordId,
    this.zone,
    this.dateTime,
    this.cotsCount,
    this.density,
    this.risk,
    this.submittedBy,
    this.confidencePercent, {
    this.adminConfirmed = false,
    this.adminRejected = false,
  });

  final int number;
  final String recordId;
  final String zone;
  final String dateTime;
  final int cotsCount;
  final double density;
  final String risk;
  final String submittedBy;
  /// Model confidence score 0–100.
  final int confidencePercent;
  /// When true, an admin confirmed a **Needs Review** submission.
  final bool adminConfirmed;
  /// When true, an admin rejected a **Needs Review** submission.
  final bool adminRejected;

  /// Effective queue status for filters and badges.
  String get displayStatus {
    if (adminConfirmed) return 'Verified';
    if (adminRejected) return 'Rejected';
    if (confidencePercent >= 85) return 'Verified';
    if (confidencePercent >= 60) return 'Needs Review';
    return 'Rejected';
  }

  AdminRecordTableRow copyWith({bool? adminConfirmed, bool? adminRejected}) {
    var c = adminConfirmed ?? this.adminConfirmed;
    var r = adminRejected ?? this.adminRejected;
    if (adminConfirmed == true) r = false;
    if (adminRejected == true) c = false;
    return AdminRecordTableRow(
      number,
      recordId,
      zone,
      dateTime,
      cotsCount,
      density,
      risk,
      submittedBy,
      confidencePercent,
      adminConfirmed: c,
      adminRejected: r,
    );
  }
}
