import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firebase_bootstrap.dart';
import '../models/capture_model.dart';
import '../models/cots_confidence_policy.dart';
import '../models/cots_detection_result.dart';
import '../models/record_collection.dart';
import 'capture_image_store.dart';
import 'cots_size_estimator.dart';
import 'processed_detection_payload.dart';
import 'scan_record_repository.dart';
import 'windows_capture_rest_service.dart';
import 'zone_assignment_service.dart';

/// Persists AI-processed detection captures — no raw data before processing.
abstract final class CaptureService {
  static final WindowsCaptureRestService _windowsRest =
      WindowsCaptureRestService();

  /// Saves processed capture metadata, then the compressed proof image.
  static Future<String> submit({
    required String uid,
    required String submittedBy,
    required String imageName,
    required Uint8List imageBytes,
    required CotsDetectionResult detection,
    required double? latitude,
    required double? longitude,
    required DateTime? dateTaken,
    required int? imageWidth,
    required int? imageHeight,
    required String notes,
    required double? depth,
    required bool? measurementReferenceVisible,
    required CotsSizeEstimate? sizeEstimate,
  }) async {
    final assignment = ZoneAssignmentService.resolveArea(
      latitude: latitude,
      longitude: longitude,
    );
    final zone = assignment?.zoneLabel ?? 'Unassigned';

    final data = ProcessedDetectionPayload.captureFields(
      uid: uid,
      submittedBy: submittedBy,
      imageName: imageName,
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
      zone: zone,
      municipality: assignment?.municipality.name ?? '',
      barangay: assignment?.barangay.name ?? '',
    );

    if (deferFirebaseUntilFirstUse) {
      final idToken = ScanRecordRepository.windowsIdToken;
      if (idToken == null) {
        throw StateError('Not signed in — cannot submit capture.');
      }
      final captureId = await _windowsRest.createCapture(
        idToken: idToken,
        uid: uid,
        submittedBy: submittedBy,
        imageName: imageName,
        detection: detection,
        latitude: latitude,
        longitude: longitude,
        dateTaken: dateTaken,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        notes: notes,
        depth: depth,
        zone: zone,
        municipality: assignment?.municipality.name ?? '',
        barangay: assignment?.barangay.name ?? '',
      );
      await CaptureImageStore.save(
        captureId: captureId,
        uid: uid,
        imageBytes: imageBytes,
      );
      return captureId;
    }

    await ensureFirebaseInitialized();
    final docRef =
        FirebaseFirestore.instance.collection(RecordCollection.captures).doc();
    final payload = Map<String, dynamic>.from(data)
      ..['display_record_id'] =
          CaptureModel.formatDisplayRecordId(docRef.id);

    await docRef.set(payload);
    await CaptureImageStore.save(
      captureId: docRef.id,
      uid: uid,
      imageBytes: imageBytes,
    );
    return docRef.id;
  }

  static Future<void> updateAdminVerification({
    required String captureId,
    required bool adminConfirmed,
    required bool adminRejected,
    required String reviewedBy,
    required List<PerCotsAdminDecision> cotsDecisions,
  }) async {
    if (captureId.isEmpty) {
      throw ArgumentError('captureId is required');
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
      await _windowsRest.updateAdminVerification(
        idToken: token,
        captureId: captureId,
        adminConfirmed: adminConfirmed,
        adminRejected: adminRejected,
        reviewedBy: reviewedBy,
        cotsDecisions: cotsDecisions,
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection(RecordCollection.captures)
        .doc(captureId)
        .update(payload);
  }
}
