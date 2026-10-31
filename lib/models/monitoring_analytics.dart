import 'dart:math' as math;

import 'activity_type.dart';
import 'cots_confidence_policy.dart';
import 'record_collection.dart';
import 'scan_record_model.dart';

/// Stage 3: honest totals. Each COTS is photographed once, so photo counts add
/// up; totals use CONFIRMED COTS, with the rest waiting or not accepted.
/// Zones are never marked cleared.
class MonitoringAnalytics {
  MonitoringAnalytics.fromRecords(
    Iterable<ScanRecordModel> input, {
    DateTime? from,
    DateTime? to,
    String? zone,
  }) {
    final unique = <String, ScanRecordModel>{
      for (final record in input)
        '${record.recordCollection}/${record.id}': record,
    };
    final all = unique.values.toList();
    zones = all.where(isCapture).map((r) => zoneName(r)).toSet().toList()
      ..sort();
    bool included(ScanRecordModel r) {
      if (zone != null && zoneName(r) != zone) return false;
      final date = r.submittedAt ?? r.dateTaken;
      if (from != null && (date == null || date.isBefore(day(from)))) {
        return false;
      }
      if (to != null &&
          (date == null ||
              !date.isBefore(day(to).add(const Duration(days: 1))))) {
        return false;
      }
      return true;
    }

    captures = all.where((r) => isCapture(r) && included(r)).toList();
    // Separate evidence and survey summaries reference captures already counted.
    final mergedRemovalCaptures = all
        .where(
            (r) => isCapture(r) && CotsActivityType.isRemoval(r.activityType))
        .map((r) => '${r.uid}/${r.id}')
        .toSet();
    removalRecords = all
        .where((r) =>
            CotsActivityType.isRemoval(r.activityType) &&
            r.recordCollection != RecordCollection.followUpSurveys &&
            !(r.recordCollection == RecordCollection.removalRecords &&
                r.id == '${r.linkedCaptureId}_removal' &&
                mergedRemovalCaptures
                    .contains('${r.uid}/${r.linkedCaptureId}')) &&
            included(r))
        .toList();
    for (final r in captures) {
      final tally = r.cotsTally;
      totalCots += math.max(0, r.aiDetectedCount);
      accepted += tally.confirmed;
      pending += tally.waiting;
      rejected += tally.notAccepted;
      if (tally.waiting > 0) pendingRecords++;
      byZone.update(zoneName(r), (value) => value + tally.confirmed,
          ifAbsent: () => tally.confirmed);
      for (final item in r.detectionReviewItems) {
        confidenceSum += item.confidencePercent;
        confidenceBands[item.band.index]++;
      }
    }
  }

  late final List<ScanRecordModel> captures;
  late final List<ScanRecordModel> removalRecords;
  late final List<String> zones;
  final Map<String, int> byZone = {};
  final List<int> confidenceBands =
      List.filled(CotsVerificationBand.values.length, 0);
  /// [totalCots] is everything the AI detected; [accepted] (confirmed),
  /// [pending] (waiting for the Expert) and [rejected] (not accepted) add up
  /// to it. [byZone] and the trend use confirmed COTS.
  int totalCots = 0, accepted = 0, pending = 0, rejected = 0;
  int pendingRecords = 0;
  double confidenceSum = 0;
  double? get averageConfidence =>
      totalCots == 0 ? null : confidenceSum / totalCots;
  int get reportedEliminated =>
      removalRecords.fold(0, (sum, r) => sum + (r.removedQuantity ?? 0));
  int get unreportedRemovals =>
      removalRecords.where((r) => r.removedQuantity == null).length;

  static bool isCapture(ScanRecordModel r) =>
      r.recordCollection == RecordCollection.captures ||
      (r.recordCollection == RecordCollection.legacyScanRecords &&
          !CotsActivityType.isRemoval(r.activityType));
  static String zoneName(ScanRecordModel r) =>
      r.zone.trim().isEmpty ? 'Unassigned' : r.zone.trim();
  static DateTime day(DateTime d) {
    final local = d.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  List<MonitoringTrendPoint> trend(
      DateTime from, DateTime to, String granularity) {
    DateTime bucket(DateTime date) {
      final d = day(date);
      if (granularity == 'Monthly') return DateTime(d.year, d.month);
      if (granularity == 'Weekly') {
        return d.subtract(Duration(days: d.weekday - 1));
      }
      return d;
    }

    final counts = <DateTime, int>{};
    final first = day(from), last = day(to);
    for (var d = first; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
      counts.putIfAbsent(bucket(d), () => 0);
    }
    for (final r in captures) {
      final when = r.submittedAt ?? r.dateTaken;
      if (when == null ||
          day(when).isBefore(first) ||
          day(when).isAfter(last)) {
        continue;
      }
      final confirmed = r.cotsTally.confirmed;
      counts.update(bucket(when), (v) => v + confirmed,
          ifAbsent: () => confirmed);
    }
    final dates = counts.keys.toList()..sort();
    return [for (final d in dates) MonitoringTrendPoint(d, counts[d]!)];
  }
}

class MonitoringTrendPoint {
  const MonitoringTrendPoint(this.date, this.count);
  final DateTime date;
  final int count;
}
