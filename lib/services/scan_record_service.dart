import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firebase_bootstrap.dart';
import '../models/activity_type.dart';
import '../models/cots_confidence_policy.dart';
import '../models/cots_detection_result.dart';
import '../models/record_collection.dart';
import 'capture_service.dart';
import 'cots_size_estimator.dart';
import 'intervention_assignment_repository.dart';
import 'notification_repository.dart';
import 'processed_detection_payload.dart';
import 'removal_record_service.dart';
import 'scan_record_repository.dart';
import 'windows_scan_record_rest_service.dart';
import 'zone_assignment_service.dart';

/// Facade for citizen science submissions — routes to captures / removal_records.
abstract final class ScanRecordService {
  static final WindowsScanRecordRestService _windowsLegacyRest =
      WindowsScanRecordRestService();

  static Future<void> submit({
    required String uid,
    required String submittedBy,
    required String imageName,
    required String imagePath,
    required Uint8List imageBytes,
    required String activityType,
    required CotsDetectionResult detection,
    required double? latitude,
    required double? longitude,
    required DateTime? dateTaken,
    required int? imageWidth,
    required int? imageHeight,
    required String notes,
    required double? depth,
    required int? confirmedRemovedQuantity,
    required bool? measurementReferenceVisible,
    required String? removalMethod,
    required CotsSizeEstimate? sizeEstimate,
    String? linkedCaptureId,
  }) async {
    if (CotsActivityType.isRemoval(activityType)) {
      final captureId = linkedCaptureId?.trim() ?? '';
      if (captureId.isEmpty) {
        throw ArgumentError(
          'Removal records must be linked to a capture (capture_id).',
        );
      }
      final removalId = await RemovalRecordService.submit(
        captureId: captureId,
        uid: uid,
        submittedBy: submittedBy,
        imageName: imageName,
        imageBytes: imageBytes,
        removedQuantity: confirmedRemovedQuantity ?? detection.count,
        removalMethod: removalMethod,
        notes: notes,
        depth: depth,
        latitude: latitude,
        longitude: longitude,
        dateTaken: dateTaken,
        verificationDetection: detection,
      );
      // Owner-initiated removals remain valid without an assignment.
      // Assignment sync is best-effort — do not fail the removal submit on
      // permission errors (common on Windows REST when rules block reads).
      try {
        final assignment =
            await InterventionAssignmentRepository.getForCapture(captureId);
        if (assignment != null && assignment.assignedToUid == uid) {
          await InterventionAssignmentRepository.markEvidenceSubmitted(
            captureId: captureId,
            removalRecordId: removalId,
          );
        }
      } catch (_) {
        // Removal record is already saved; assignment update is optional.
      }
      return;
    }

    final captureId = await CaptureService.submit(
      uid: uid,
      submittedBy: submittedBy,
      imageName: imageName,
      imageBytes: imageBytes,
      detection: detection,
      latitude: latitude,
      longitude: longitude,
      dateTaken: dateTaken,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      notes: notes,
      depth: depth,
      measurementReferenceVisible: measurementReferenceVisible,
      sizeEstimate: sizeEstimate,
    );
    await NotificationRepository.createScanSubmitted(
      recipientUid: uid,
      recordId: captureId,
      detectedCount: detection.count,
      zone: ZoneAssignmentService.assignZone(
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  static List<CotsBoundingBox> detectionBoxesForStorage({
    required CotsDetectionResult detection,
    required int? imageWidth,
    required int? imageHeight,
  }) {
    return ProcessedDetectionPayload.detectionBoxesForStorage(
      detection: detection,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  static Future<void> updateAdminVerification({
    required String recordId,
    required String recordCollection,
    required bool adminConfirmed,
    required bool adminRejected,
    required String reviewedBy,
    required List<PerCotsAdminDecision> cotsDecisions,
  }) async {
    if (recordId.isEmpty) {
      throw ArgumentError('recordId is required');
    }

    if (recordCollection == RecordCollection.captures) {
      await CaptureService.updateAdminVerification(
        captureId: recordId,
        adminConfirmed: adminConfirmed,
        adminRejected: adminRejected,
        reviewedBy: reviewedBy,
        cotsDecisions: cotsDecisions,
      );
      return;
    }

    final payload = <String, dynamic>{
      'admin_confirmed': adminConfirmed,
      'admin_rejected': adminRejected,
      'admin_reviewed_by': reviewedBy,
      'admin_reviewed_at': FieldValue.serverTimestamp(),
      'admin_cots_decisions':
          PerCotsAdminDecisionX.listToStorage(cotsDecisions),
    };

    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) {
        throw StateError('Not signed in — cannot save admin review.');
      }
      await _windowsLegacyRest.updateAdminVerification(
        idToken: token,
        recordId: recordId,
        adminConfirmed: adminConfirmed,
        adminRejected: adminRejected,
        reviewedBy: reviewedBy,
        cotsDecisions: cotsDecisions,
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection(RecordCollection.legacyScanRecords)
        .doc(recordId)
        .update(payload);
  }
}
