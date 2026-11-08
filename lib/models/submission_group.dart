import 'dart:convert';
import 'submission_identity.dart';

import 'activity_type.dart';
import 'cots_tally.dart';
import 'record_collection.dart';
import 'scan_record_model.dart';
import 'zone_review.dart';

enum SubmissionReviewStatus {
  pendingReview,
  processing,
  accepted,
  partiallyAccepted,
  retakeRequired,
  notApplicable,
}

/// Read-only presentation grouping. Each child retains its original identity,
/// photo, GPS, time, detections and decisions; nothing is merged in storage.
class SubmissionGroup {
  SubmissionGroup._(this.key, List<ScanRecordModel> records,
      {required this.hasCrossSiteEncounter})
      : records = List.unmodifiable(records);

  final String key;
  final List<ScanRecordModel> records;

  /// Existing removal evidence can contain a whole-batch total on its first
  /// photo. Later screens must not treat that as a per-site removal total.
  final bool hasCrossSiteEncounter;

  String get ownerId => records.first.uid;
  String get encounterId => records.first.encounterId;
  String get siteId => records.first.monitoringAreaId;
  bool get hasBatch =>
      ownerId.isNotEmpty &&
      records.first.id.isNotEmpty &&
      records.first.recordCollection == RecordCollection.captures &&
      encounterId.isNotEmpty &&
      siteId.isNotEmpty &&
      records.first.sourceCapture?.followUpSurveyId.isNotEmpty != true;
  String get displayId => hasBatch
      ? SubmissionIdentity.fromKey(key)
      : records.first.displayRecordId;
  String statusLabel({bool pendingSync = false}) {
    if (pendingSync) return 'Pending synchronization';
    if (!hasBatch) return records.first.userStatusLabel;
    return switch (reviewStatus) {
      SubmissionReviewStatus.pendingReview => 'Requires Expert Validation',
      SubmissionReviewStatus.processing => 'Processing evidence',
      SubmissionReviewStatus.accepted => 'Accepted',
      SubmissionReviewStatus.partiallyAccepted => 'Partially accepted',
      SubmissionReviewStatus.retakeRequired => 'Retake Photo',
      SubmissionReviewStatus.notApplicable => records.first.userStatusLabel,
    };
  }

  int get photoCount => records.where(_isPhoto).length;
  CotsTally get cotsTally => records.where(_isPhoto).fold(
      CotsTally.zero,
      (total, record) =>
          total +
          (record.sourceCapture?.serverStatus == 'pending'
              ? CotsTally(
                  confirmed: 0, waiting: record.aiDetectedCount, notAccepted: 0)
              : record.cotsTally));
  int get detectedCount => cotsTally.total;
  DateTime? get latestSubmittedAt {
    DateTime? latest;
    for (final record in records) {
      final time = record.submittedAt ?? record.dateTaken;
      if (time != null && (latest == null || time.isAfter(latest))) {
        latest = time;
      }
    }
    return latest;
  }

  SubmissionReviewStatus get reviewStatus {
    if (photoCount == 0) return SubmissionReviewStatus.notApplicable;
    if (records.where(_isPhoto).any((record) =>
        record.sourceCapture?.serverStatus != 'pending' &&
        (record.cotsTally.waiting > 0 ||
            ZoneReview.isWaiting(
                assignedTo: record.zoneAssignedTo,
                confirmed: record.adminConfirmed,
                rejected: record.adminRejected)))) {
      return SubmissionReviewStatus.pendingReview;
    }
    if (records
        .where(_isPhoto)
        .any((record) => record.sourceCapture?.serverStatus == 'pending')) {
      return SubmissionReviewStatus.processing;
    }
    final tally = cotsTally;
    if (tally.confirmed == 0) return SubmissionReviewStatus.retakeRequired;
    if (tally.notAccepted > 0 ||
        records
            .where(_isPhoto)
            .any((record) => record.userStatusLabel == 'Retake Photo')) {
      return SubmissionReviewStatus.partiallyAccepted;
    }
    return SubmissionReviewStatus.accepted;
  }

  /// Missing batch/site/owner metadata is never guessed from GPS or dates.
  /// Follow-up surveys, linked removals and unrelated legacy rows stay separate.
  static List<SubmissionGroup> fromRecords(Iterable<ScanRecordModel> input) {
    final groups = <String, List<ScanRecordModel>>{};
    final seen = <String>{};
    final sitesByEncounter = <String, Set<String>>{};
    var index = 0;
    for (final record in input) {
      final identity =
          jsonEncode([record.uid, record.recordCollection, record.id]);
      if (record.id.isNotEmpty && !seen.add(identity)) continue;
      final batch = _batchKey(record);
      if (batch != null) {
        sitesByEncounter.putIfAbsent(batch, () => {}).add(
            record.monitoringAreaId.isEmpty
                ? identity
                : record.monitoringAreaId);
      }
      final canGroup = batch != null && record.monitoringAreaId.isNotEmpty;
      final key = canGroup
          ? jsonEncode([
              'batch-site',
              record.uid,
              record.encounterId,
              record.monitoringAreaId
            ])
          : jsonEncode([
              'single',
              record.uid,
              record.recordCollection,
              record.id,
              if (record.id.isEmpty) index
            ]);
      groups.putIfAbsent(key, () => []).add(record);
      index++;
    }
    final result = <SubmissionGroup>[];
    for (final entry in groups.entries) {
      entry.value.sort((a, b) => a.id.compareTo(b.id));
      final batch = _batchKey(entry.value.first);
      result.add(SubmissionGroup._(entry.key, entry.value,
          hasCrossSiteEncounter:
              batch != null && sitesByEncounter[batch]!.length > 1));
    }
    result.sort((a, b) {
      final order = (b.latestSubmittedAt ?? DateTime(1970))
          .compareTo(a.latestSubmittedAt ?? DateTime(1970));
      return order == 0 ? a.key.compareTo(b.key) : order;
    });
    return List.unmodifiable(result);
  }

  static String? _batchKey(ScanRecordModel record) =>
      record.recordCollection == RecordCollection.captures &&
              record.uid.isNotEmpty &&
              record.id.isNotEmpty &&
              record.encounterId.isNotEmpty &&
              record.sourceCapture?.followUpSurveyId.isNotEmpty != true
          ? jsonEncode([record.uid, record.encounterId])
          : null;

  static bool _isPhoto(ScanRecordModel record) =>
      record.recordCollection == RecordCollection.captures ||
      (record.recordCollection == RecordCollection.legacyScanRecords &&
          !CotsActivityType.isRemoval(record.activityType));
}
