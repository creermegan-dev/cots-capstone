import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firebase_bootstrap.dart';
import '../core/supabase_config.dart';
import '../models/activity_type.dart';
import '../models/cots_confidence_policy.dart';
import '../models/cots_detection_result.dart';
import '../models/record_collection.dart';
import '../models/follow_up_monitoring_model.dart';
import 'capture_service.dart';
import 'capture_repository.dart';
import 'cots_size_estimator.dart';
import 'follow_up_monitoring_repository.dart';
import 'intervention_assignment_repository.dart';
import 'notification_repository.dart';
import 'processed_detection_payload.dart';
import 'removal_record_service.dart';
import 'scan_record_repository.dart';
import 'supabase_evidence_service.dart';
import 'windows_scan_record_rest_service.dart';
import 'zone_assignment_service.dart';

/// Facade for citizen science submissions — routes to captures / removal_records.
typedef RecordEvidenceProgressCallback = Future<void> Function(
  EvidencePurpose purpose,
  EvidenceUploadStage stage,
);

abstract final class ScanRecordService {
  static final WindowsScanRecordRestService _windowsLegacyRest =
      WindowsScanRecordRestService();

  static Future<String?> submit({
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
    String? encounterId,
    bool isFollowUp = false,
    String? submissionId,
    String? followUpSurveyId,
    DateTime? followUpSurveyDate,
    FollowUpAssignmentModel? followUpAssignment,
    void Function(String message)? onWarning,
    EvidenceImagePayload? evidence,
    RecordEvidenceProgressCallback? onEvidenceProgress,
    bool? gpsFromPhoto,
    bool? timeFromPhoto,
  }) async {
    if (CotsActivityType.isRemoval(activityType)) {
      var captureId = linkedCaptureId?.trim() ?? '';
      final isNewEncounter = captureId.isEmpty;
      if ((confirmedRemovedQuantity != null && confirmedRemovedQuantity < 0) ||
          removalMethod == null ||
          removalMethod.trim().isEmpty) {
        throw ArgumentError(
            'Select a removal method and use a valid quantity if provided.');
      }
      if (isNewEncounter) {
        if (submissionId == null || submissionId.isEmpty) {
          throw ArgumentError(
              'A stable submission ID is required for a new encounter.');
        }
        // Create this encounter's own capture, never ask the diver for an older record.
        captureId = await CaptureService.submit(
          submissionId: submissionId,
          encounterId: encounterId,
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
          gpsFromPhoto: gpsFromPhoto,
          timeFromPhoto: timeFromPhoto,
          evidence: evidence,
          onEvidenceProgress: onEvidenceProgress == null
              ? null
              : (stage) => onEvidenceProgress(
                    EvidencePurpose.detection,
                    stage,
                  ),
        );
      }
      final removalId = await RemovalRecordService.submit(
        encounterId: isNewEncounter ? encounterId : null,
        submissionId: submissionId == null ? null : '${submissionId}_removal',
        captureId: captureId,
        uid: uid,
        submittedBy: submittedBy,
        imageName: imageName,
        imageBytes: imageBytes,
        removedQuantity: confirmedRemovedQuantity,
        removalMethod: removalMethod,
        notes: notes,
        depth: depth,
        latitude: latitude,
        longitude: longitude,
        dateTaken: dateTaken,
        verificationDetection: detection,
        gpsFromPhoto: gpsFromPhoto,
        evidence: evidence,
        onEvidenceProgress: onEvidenceProgress == null
            ? null
            : (stage) => onEvidenceProgress(
                  EvidencePurpose.elimination,
                  stage,
                ),
      );
      // Owner-initiated removals remain valid without an assignment.
      // Assignment sync is best-effort — do not fail the removal submit on
      // permission errors (common on Windows REST when rules block reads).
      // Assignments are still Firebase-only, so Supabase builds skip this.
      if (!SupabaseConfig.isConfigured) {
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
      }
      if (isNewEncounter && !SupabaseConfig.isConfigured) {
        try {
          await FollowUpMonitoringRepository.considerNewDetection(
            captureId: captureId,
            uid: uid,
            diverName: submittedBy,
            detection: detection,
            latitude: latitude,
            longitude: longitude,
            dateTaken: dateTaken,
            submittedAt: DateTime.now(),
            imageWidth: imageWidth,
            imageHeight: imageHeight,
          );
        } catch (_) {
          onWarning?.call(
              'Record saved. Follow-up monitoring could not be updated.');
        }
      }
      return captureId;
    }

    final captureId = await CaptureService.submit(
      submissionId: submissionId,
      encounterId: encounterId,
      followUpSurveyId: followUpSurveyId,
      followUpSurveyDate: followUpSurveyDate,
      followUpAssignment: followUpAssignment,
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
      gpsFromPhoto: gpsFromPhoto,
      timeFromPhoto: timeFromPhoto,
      evidence: evidence,
      onEvidenceProgress: onEvidenceProgress == null
          ? null
          : (stage) => onEvidenceProgress(
                EvidencePurpose.detection,
                stage,
              ),
    );
    // Supabase builds: the database creates the notifications, and follow-up
    // monitoring has not moved to Supabase yet, so these Firebase-only steps
    // run only in Firebase builds.
    if (SupabaseConfig.isConfigured) return captureId;
    final submittedAt = DateTime.now();
    if (!isFollowUp) {
      try {
        await FollowUpMonitoringRepository.considerNewDetection(
          captureId: captureId,
          uid: uid,
          diverName: submittedBy,
          detection: detection,
          latitude: latitude,
          longitude: longitude,
          dateTaken: dateTaken,
          submittedAt: submittedAt,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        );
      } catch (_) {
        onWarning?.call(
            'Detection saved. Follow-up assignment could not be completed; retry from Follow-up.');
      }
    }
    await NotificationRepository.createScanSubmitted(
      recipientUid: uid,
      recordId: captureId,
      detectedCount: detection.count,
      zone: ZoneAssignmentService.assignZone(
        latitude: latitude,
        longitude: longitude,
      ),
    );
    return captureId;
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
    String reason = '',
  }) async {
    if (recordId.isEmpty) {
      throw ArgumentError('recordId is required');
    }

    if (SupabaseConfig.isConfigured) {
      if (recordCollection != RecordCollection.captures) {
        throw StateError(
          'Only detections are reviewed by the Expert. Removal records are '
          'checked through their linked detection.',
        );
      }
      // Follow-up assignment is created by the server when it finalizes the
      // capture, so the Firebase follow-up step below is not used here.
      await CaptureService.updateAdminVerification(
        captureId: recordId,
        adminConfirmed: adminConfirmed,
        adminRejected: adminRejected,
        reviewedBy: reviewedBy,
        cotsDecisions: cotsDecisions,
        reason: reason,
      );
      return;
    }

    if (recordCollection == RecordCollection.captures) {
      await CaptureService.updateAdminVerification(
        captureId: recordId,
        adminConfirmed: adminConfirmed,
        adminRejected: adminRejected,
        reviewedBy: reviewedBy,
        cotsDecisions: cotsDecisions,
        reason: reason,
      );
      final capture = await CaptureRepository.getById(recordId);
      if (capture != null) {
        await FollowUpMonitoringRepository.considerExpertValidatedCapture(
          capture,
        );
      }
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
      await _syncLegacyFollowUp(recordId);
      return;
    }

    await FirebaseFirestore.instance
        .collection(RecordCollection.legacyScanRecords)
        .doc(recordId)
        .update(payload);
    await _syncLegacyFollowUp(recordId);
  }

  static Future<void> _syncLegacyFollowUp(String recordId) async {
    final history = await FollowUpMonitoringRepository.loadDetectionHistory();
    final matches = history.where((capture) =>
        capture.id == recordId &&
        capture.sourceCollection == RecordCollection.legacyScanRecords);
    if (matches.isNotEmpty) {
      await FollowUpMonitoringRepository.considerExpertValidatedCapture(
          matches.first);
    }
  }
}
