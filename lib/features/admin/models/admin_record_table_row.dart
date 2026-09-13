import '../../../models/cots_confidence_policy.dart';
import '../../../models/cots_detection_result.dart';
import '../../../models/record_collection.dart';

/// Row model for the Records / Submissions table (shared with details navigation).
///
/// Verification bands — see [CotsConfidencePolicy] (evaluated per COTS, not average alone):
  /// - **Accepted**: every COTS ≥80%, or admin finished per-COTS review
  /// - **Under Review**: any COTS is 20–79% and awaits admin verification
/// - **Rejected / Retake**: all COTS below 20%, or admin rejected after review
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
    this.activityType = 'Detection Only',
    this.aiCount,
    this.removedQuantity,
    this.averageSizeCm,
    this.captureSource = 'GoPro Image',
    this.documentId = '',
    this.imageName = '',
    this.notes = '',
    this.dateCaptured = '',
    this.dateUploaded = '',
    this.latitude,
    this.longitude,
    this.imagePath = '',
    this.imageUrl = '',
    this.storageObjectPath = '',
    this.detectionBoxes = const [],
    this.imageWidth = 0,
    this.imageHeight = 0,
    this.adminCotsDecisions = const [],
    this.recordCollection = RecordCollection.legacyScanRecords,
    this.linkedCaptureId,
    this.linkedCaptureDisplayId,
    this.ownerUid = '',
  });

  final int number;
  final String recordId;
  final String zone;
  final String dateTime;
  final int cotsCount;
  final double density;
  final String risk;
  final String submittedBy;
  final int confidencePercent;
  final bool adminConfirmed;
  final bool adminRejected;
  final String activityType;
  final int? aiCount;
  final int? removedQuantity;
  final double? averageSizeCm;
  final String captureSource;
  final String documentId;
  final String imageName;
  final String notes;
  final String dateCaptured;
  final String dateUploaded;
  final double? latitude;
  final double? longitude;
  final String imagePath;
  final String imageUrl;
  final String storageObjectPath;
  final List<CotsBoundingBox> detectionBoxes;
  final int imageWidth;
  final int imageHeight;
  final List<PerCotsAdminDecision> adminCotsDecisions;
  final String recordCollection;
  final String? linkedCaptureId;
  final String? linkedCaptureDisplayId;
  final String ownerUid;

  int get displayAiCount => aiCount ?? cotsCount;

  List<CotsDetectionReviewItem> get detectionReviewItems =>
      CotsConfidencePolicy.buildDetectionItems(
        count: cotsCount,
        averagePercent: confidencePercent,
        boxes: detectionBoxes.isNotEmpty ? detectionBoxes : null,
        imageWidth: imageWidth > 0 ? imageWidth : 1920,
        imageHeight: imageHeight > 0 ? imageHeight : 1080,
      );

  String get displayStatus => CotsConfidencePolicy.adminStatusKeyFromItems(
        items: detectionReviewItems,
        adminConfirmed: adminConfirmed,
        adminRejected: adminRejected,
      );

  /// User-facing status labels in admin records UI.
  String get displayStatusLabel {
    return switch (displayStatus) {
      'Verified' => 'Accepted',
      'Needs Review' => 'Under Review',
      'Rejected' => 'Rejected',
      _ => displayStatus,
    };
  }

  AdminRecordTableRow copyWith({
    bool? adminConfirmed,
    bool? adminRejected,
    List<PerCotsAdminDecision>? adminCotsDecisions,
  }) {
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
      activityType: activityType,
      aiCount: aiCount,
      removedQuantity: removedQuantity,
      averageSizeCm: averageSizeCm,
      captureSource: captureSource,
      documentId: documentId,
      imageName: imageName,
      notes: notes,
      dateCaptured: dateCaptured,
      dateUploaded: dateUploaded,
      latitude: latitude,
      longitude: longitude,
      imagePath: imagePath,
      imageUrl: imageUrl,
      storageObjectPath: storageObjectPath,
      detectionBoxes: detectionBoxes,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      adminCotsDecisions: adminCotsDecisions ?? this.adminCotsDecisions,
      recordCollection: recordCollection,
      linkedCaptureId: linkedCaptureId,
      linkedCaptureDisplayId: linkedCaptureDisplayId,
      ownerUid: ownerUid,
    );
  }
}
