/// Stage 2 (claude/agreed_workflow_decisions.md): another Diver's record in
/// an assigned zone waits for the Expert's approval. The database decides
/// which records these are; this file keeps the agreed wording in one place.
abstract final class ZoneReview {
  /// The agreed message for the Diver whose record was sent to the Expert.
  static String waitingMessage(String assignedTo) =>
      'This zone is currently assigned to $assignedTo. '
      'Your record was sent to the Expert for review.';

  /// Agreed status for the other Diver's waiting record.
  static const statusLabel = 'Unassigned Diver - waiting for Expert';

  static const expertTitle = 'Another Diver in an assigned zone';

  /// What the Expert checks before approving.
  static const expertChecks = [
    'Right place',
    'Not a duplicate',
    'Real COTS',
    'Sensible count',
  ];

  static const rejectReasonRequired = 'Give a reason to reject this record.';

  /// Whether the record still waits for the Expert. [assignedTo] is empty
  /// for every other record.
  static bool isWaiting({
    required String assignedTo,
    required bool confirmed,
    required bool rejected,
  }) =>
      assignedTo.isNotEmpty && !confirmed && !rejected;

  /// The error shown when the Expert rejects such a record without a reason.
  static String? rejectReasonError({
    required String assignedTo,
    required String reason,
  }) =>
      assignedTo.isNotEmpty && reason.trim().isEmpty
          ? rejectReasonRequired
          : null;
}
