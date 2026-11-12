import 'activity_type.dart';

/// Stage 3 (claude/agreed_workflow_decisions.md): honest counts. Every total
/// shows confirmed COTS, with the rest as waiting or not accepted; together
/// they add up to what the AI detected.
class CotsTally {
  const CotsTally({
    required this.confirmed,
    required this.waiting,
    required this.notAccepted,
  });

  static const zero = CotsTally(confirmed: 0, waiting: 0, notAccepted: 0);

  /// Counted: the Expert did not reject them (Stage 1-2 rules).
  final int confirmed;

  /// Waiting for the Expert (20-84% COTS, or another Diver's record in an
  /// assigned zone).
  final int waiting;

  /// Rejected by the Expert, in a rejected record, or below 20%.
  final int notAccepted;

  int get total => confirmed + waiting + notAccepted;

  CotsTally operator +(CotsTally other) => CotsTally(
        confirmed: confirmed + other.confirmed,
        waiting: waiting + other.waiting,
        notAccepted: notAccepted + other.notAccepted,
      );
}

/// Agreed report wording.
abstract final class HonestReport {
  static const confirmedLabel = 'COTS found and removed (confirmed)';
  static const waitingLabel = 'Waiting for Expert';
  static const notAcceptedLabel = 'Not accepted';
}

/// Confirmed COTS and number of removals for one removal method.
class RemovalMethodCount {
  const RemovalMethodCount({
    required this.method,
    required this.cots,
    required this.removals,
  });

  factory RemovalMethodCount.fromJson(Map<String, dynamic> json) =>
      RemovalMethodCount(
        method: json['method']?.toString() ?? '',
        cots: (json['cots'] as num?)?.round() ?? 0,
        removals: (json['removals'] as num?)?.round() ?? 0,
      );

  final String method;
  final int cots;
  final int removals;

  static const manualLabel = 'Manual removal';
  static const vinegarLabel = 'Vinegar injection';
  static const oxBileLabel = 'Ox bile injection';
  static const otherLabel = 'Other (older records)';

  /// The three current methods keep their own row; everything else (older
  /// methods such as Community Cleanup) is grouped as "Other (older
  /// records)". Fixed order, so each method keeps its colour.
  static List<RemovalMethodCount> group(Iterable<RemovalMethodCount> rows) {
    const order = [manualLabel, vinegarLabel, oxBileLabel, otherLabel];
    final cots = {for (final label in order) label: 0};
    final removals = {for (final label in order) label: 0};
    for (final row in rows) {
      final label = labelFor(row.method);
      cots[label] = cots[label]! + row.cots;
      removals[label] = removals[label]! + row.removals;
    }
    return [
      for (final label in order)
        if (cots[label]! > 0)
          RemovalMethodCount(
              method: label, cots: cots[label]!, removals: removals[label]!),
    ];
  }

  static String labelFor(String stored) {
    final value = stored.trim().toLowerCase();
    if (value == RemovalMethod.manual.toLowerCase()) return manualLabel;
    if (value == RemovalMethod.vinegar.toLowerCase()) return vinegarLabel;
    if (value == RemovalMethod.oxBile.toLowerCase()) return oxBileLabel;
    return otherLabel;
  }
}
