import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firebase_bootstrap.dart';
import '../models/cots_detection_result.dart';
import '../models/removal_record_model.dart';
import '../models/record_collection.dart';
import 'processed_detection_payload.dart';
import 'removal_record_image_store.dart';
import 'scan_record_repository.dart';
import 'windows_removal_record_rest_service.dart';
import 'zone_assignment_service.dart';

/// Persists removal activities linked to an existing capture via `capture_id`.
abstract final class RemovalRecordService {
  static final WindowsRemovalRecordRestService _windowsRest =
      WindowsRemovalRecordRestService();

  static Future<String> submit({
    required String captureId,
    required String uid,
    required String submittedBy,
    required String imageName,
    required Uint8List imageBytes,
    required int removedQuantity,
    required String? removalMethod,
    required String notes,
    required double? depth,
    required double? latitude,
    required double? longitude,
    required DateTime? dateTaken,
    CotsDetectionResult? verificationDetection,
  }) async {
    if (captureId.trim().isEmpty) {
      throw ArgumentError('captureId is required for removal records.');
    }

    final assignment = ZoneAssignmentService.resolveArea(
      latitude: latitude,
      longitude: longitude,
    );
    final zone = assignment?.zoneLabel ?? 'Unassigned';

    final data = ProcessedDetectionPayload.removalFields(
      captureId: captureId,
      uid: uid,
      submittedBy: submittedBy,
      imageName: imageName,
      removedQuantity: removedQuantity,
      removalMethod: removalMethod,
      notes: notes,
      depth: depth,
      latitude: latitude,
      longitude: longitude,
      dateTaken: dateTaken,
      zone: zone,
      municipality: assignment?.municipality.name ?? '',
      barangay: assignment?.barangay.name ?? '',
      aiVerifiedCount: verificationDetection?.count,
      aiConfidence: verificationDetection?.confidence,
    );

    if (deferFirebaseUntilFirstUse) {
      final idToken = ScanRecordRepository.windowsIdToken;
      if (idToken == null) {
        throw StateError('Not signed in — cannot submit removal record.');
      }
      final removalId = await _windowsRest.createRemovalRecord(
        idToken: idToken,
        captureId: captureId,
        uid: uid,
        submittedBy: submittedBy,
        imageName: imageName,
        removedQuantity: removedQuantity,
        removalMethod: removalMethod,
        notes: notes,
        depth: depth,
        latitude: latitude,
        longitude: longitude,
        dateTaken: dateTaken,
        zone: zone,
        municipality: assignment?.municipality.name ?? '',
        barangay: assignment?.barangay.name ?? '',
        aiVerifiedCount: verificationDetection?.count,
        aiConfidence: verificationDetection?.confidence,
      );
      await RemovalRecordImageStore.save(
        removalId: removalId,
        uid: uid,
        captureId: captureId,
        imageBytes: imageBytes,
      );
      return removalId;
    }

    await ensureFirebaseInitialized();
    final docRef = FirebaseFirestore.instance
        .collection(RecordCollection.removalRecords)
        .doc();
    final payload = Map<String, dynamic>.from(data)
      ..['display_record_id'] =
          RemovalRecordModel.formatDisplayRecordId(docRef.id);

    await docRef.set(payload);
    await RemovalRecordImageStore.save(
      removalId: docRef.id,
      uid: uid,
      captureId: captureId,
      imageBytes: imageBytes,
    );
    return docRef.id;
  }
}
