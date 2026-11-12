import 'dart:convert';

import '../features/admin/models/admin_record_table_row.dart';
import 'capture_model.dart';
import 'scan_record_model.dart';
import 'submission_group.dart';
import 'submission_identity.dart';
import 'activity_type.dart';
import 'record_collection.dart';

/// Staff/report presentation adapters. Summary rows have no writable photo ID.
abstract final class StaffSubmissionRows {
  static ScanRecordModel photo(AdminRecordTableRow row) {
    final capture = CaptureModel(
      id: row.documentId,
      uid: row.ownerUid,
      submittedBy: row.submittedBy,
      imageName: row.imageName,
      storageObjectPath: row.storageObjectPath,
      aiDetectedCount: row.displayAiCount,
      confidence: row.confidencePercent / 100,
      captureSource: row.captureSource,
      modelName: row.modelName,
      expertConfirmedCount: row.expertConfirmedCount,
      zone: row.zone,
      notes: row.notes,
      submittedAt: row.submittedAt,
      dateTaken: row.capturedAt,
      monitoringAreaId: row.siteId,
      encounterId: row.encounterId,
      followUpSurveyId: row.followUpSurveyId,
      serverStatus: row.serverStatus,
      latitude: row.latitude,
      longitude: row.longitude,
      detectionBoxes: row.detectionBoxes,
      imageWidth: row.imageWidth,
      imageHeight: row.imageHeight,
      adminConfirmed: row.adminConfirmed,
      adminRejected: row.adminRejected,
      adminCotsDecisions: row.adminCotsDecisions,
      autoApproveMin: row.autoApproveMin,
      storedDisplayRecordId: row.recordId,
      confirmedCount: row.cotsTally.confirmed,
      waitingCount: row.cotsTally.waiting,
      zoneAssignedTo: row.zoneAssignedTo,
      locationSource: row.locationSource,
      timeSource: row.timeSource,
      averageSizeCm: row.averageSizeCm,
    );
    return ScanRecordModel(
        id: capture.id,
        uid: capture.uid,
        submittedBy: capture.submittedBy,
        imageName: row.imageName,
        imagePath: row.imagePath,
        imageUrl: row.imageUrl,
        storageObjectPath: row.storageObjectPath,
        activityType: row.activityType.toLowerCase().contains('removal')
            ? CotsActivityType.removalActivity
            : CotsActivityType.detectionOnly,
        aiDetectedCount: capture.aiDetectedCount,
        confidence: capture.confidence,
        captureSource: row.captureSource,
        zone: row.zone,
        notes: row.notes,
        submittedAt: row.submittedAt,
        dateTaken: row.capturedAt,
        latitude: row.latitude,
        longitude: row.longitude,
        averageSizeCm: row.averageSizeCm,
        removedQuantity: row.removedQuantity,
        detectionBoxes: row.detectionBoxes,
        imageWidth: row.imageWidth,
        imageHeight: row.imageHeight,
        adminConfirmed: row.adminConfirmed,
        adminRejected: row.adminRejected,
        adminCotsDecisions: row.adminCotsDecisions,
        confidenceAutoApproveMin: row.autoApproveMin,
        storedDisplayRecordId: row.recordId,
        recordCollection: row.recordCollection,
        sourceCapture: capture,
        locationSource: row.locationSource,
        timeSource: row.timeSource);
  }

  static SubmissionGroup groupFor(AdminRecordTableRow row) =>
      SubmissionGroup.fromRecords(row.submissionPhotos.map(photo)).single;

  static List<AdminRecordTableRow> group(Iterable<AdminRecordTableRow> input) {
    final buckets = <String, List<AdminRecordTableRow>>{};
    final seen = <String>{};
    var unidentified = 0;
    for (final entry in input) {
      for (final row
          in entry.isSubmissionSummary ? entry.submissionPhotos : [entry]) {
        final id = row.documentId.isEmpty ? row.recordId : row.documentId;
        final identity = jsonEncode([
          row.ownerUid,
          row.recordCollection,
          id.isEmpty ? 'unidentified-${unidentified++}' : id
        ]);
        if (id.isNotEmpty && !seen.add(identity)) continue;
        final eligible = row.documentId.isNotEmpty &&
            row.recordCollection == RecordCollection.captures &&
            row.followUpSurveyId.isEmpty &&
            row.submissionId.isNotEmpty &&
            row.submissionId ==
                SubmissionIdentity.forBatch(
                    row.ownerUid, row.encounterId, row.siteId);
        final key = eligible ? row.submissionId : 'single/$identity';
        buckets.putIfAbsent(key, () => []).add(row);
      }
    }
    return [
      for (final entry in buckets.entries)
        if (entry.key.startsWith('single/'))
          entry.value.single
        else
          _summary(entry.value)
    ];
  }

  static AdminRecordTableRow _summary(List<AdminRecordTableRow> photos) {
    final group = SubmissionGroup.fromRecords(photos.map(photo)).single;
    final first = photos.first;
    final latest = photos.reduce((a, b) => (b.submittedAt ?? DateTime(1970))
            .isAfter(a.submittedAt ?? DateTime(1970))
        ? b
        : a);
    final status = switch (group.reviewStatus) {
      SubmissionReviewStatus.pendingReview => 'Under Review',
      SubmissionReviewStatus.processing => 'Processing evidence',
      SubmissionReviewStatus.accepted => 'Accepted',
      SubmissionReviewStatus.partiallyAccepted => 'Partially accepted',
      SubmissionReviewStatus.retakeRequired => 'Rejected',
      SubmissionReviewStatus.notApplicable => first.displayStatusLabel,
    };
    return AdminRecordTableRow(
      first.number,
      group.displayId,
      first.zone,
      first.dateTime,
      group.detectedCount,
      null,
      'Per photo',
      first.submittedBy,
      0,
      activityType: '${photos.length} photos',
      aiCount: group.detectedCount,
      captureSource: 'Per photo',
      dateUploaded: latest.dateUploaded,
      dateCaptured: 'Per photo',
      ownerUid: first.ownerUid,
      encounterId: first.encounterId,
      siteId: first.siteId,
      submissionId: group.displayId,
      submissionPhotos: List.unmodifiable(photos),
      submissionStatus: status,
      cotsTally: group.cotsTally,
    );
  }
}
