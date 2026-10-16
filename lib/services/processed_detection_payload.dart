import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/activity_type.dart';
import '../models/cots_confidence_policy.dart';
import '../models/cots_detection_result.dart';
import 'cots_size_estimator.dart';

/// Builds Firestore payloads for AI-processed capture data (no raw image bytes).
abstract final class ProcessedDetectionPayload {
  static Map<String, dynamic> captureFields({
    required String uid,
    required String submittedBy,
    required String imageName,
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
    required String zone,
    String monitoringAreaId = '',
    String municipality = '',
    String barangay = '',
  }) {
    final data = <String, dynamic>{
      'uid': uid,
      'submitted_by': submittedBy,
      'image_name': imageName,
      'has_processed_image': true,
      'ai_detected_count': detection.count,
      'cots_count': detection.count,
      'confidence': detection.confidence,
      'capture_source': CaptureSource.goProUnderwaterImage,
      'citizen_contribution': true,
      'notes': notes,
      'zone': zone,
      if (monitoringAreaId.isNotEmpty) 'monitoring_area_id': monitoringAreaId,
      'municipality': municipality,
      'barangay': barangay,
      'gps': {'latitude': latitude, 'longitude': longitude},
      'date_taken':
          dateTaken != null ? Timestamp.fromDate(dateTaken) : null,
      'resolution': {'width': imageWidth, 'height': imageHeight},
      'depth': depth,
      'capture_depth': depth,
      'capture_depth_unit': depth != null ? 'meters' : null,
      'processed_at': FieldValue.serverTimestamp(),
      'submitted_at': FieldValue.serverTimestamp(),
    };

    if (measurementReferenceVisible != null) {
      data['measurement_reference_visible'] = measurementReferenceVisible;
    }

    if (sizeEstimate != null) {
      data['average_size_cm'] = sizeEstimate.averageCm;
      data['minimum_size_cm'] = sizeEstimate.minimumCm;
      data['maximum_size_cm'] = sizeEstimate.maximumCm;
      data['size_confidence_score'] = sizeEstimate.confidenceScore;
      data['estimated_sizes_cm'] = sizeEstimate.perCotsCm;
    }

    final detectionBoxes = detectionBoxesForStorage(
      detection: detection,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
    if (detectionBoxes.isNotEmpty) {
      data['detections'] = detectionBoxes.map((b) => b.toMap()).toList();
    }

    return data;
  }

  static Map<String, dynamic> removalFields({
    required String captureId,
    required String uid,
    required String submittedBy,
    required String imageName,
    required int removedQuantity,
    required String? removalMethod,
    required String notes,
    required double? depth,
    required double? latitude,
    required double? longitude,
    required DateTime? dateTaken,
    required String zone,
    String municipality = '',
    String barangay = '',
    int? aiVerifiedCount,
    double? aiConfidence,
  }) {
    return <String, dynamic>{
      'capture_id': captureId,
      'uid': uid,
      'submitted_by': submittedBy,
      'image_name': imageName,
      'has_processed_image': true,
      'removed_quantity': removedQuantity,
      'removal_method': removalMethod ?? '',
      'notes': notes,
      'zone': zone,
      'municipality': municipality,
      'barangay': barangay,
      'gps': {'latitude': latitude, 'longitude': longitude},
      'date_taken':
          dateTaken != null ? Timestamp.fromDate(dateTaken) : null,
      'depth': depth,
      'capture_depth': depth,
      'capture_depth_unit': depth != null ? 'meters' : null,
      if (aiVerifiedCount != null) 'ai_verified_count': aiVerifiedCount,
      if (aiConfidence != null) 'ai_confidence': aiConfidence,
      'processed_at': FieldValue.serverTimestamp(),
      'submitted_at': FieldValue.serverTimestamp(),
    };
  }

  static List<CotsBoundingBox> detectionBoxesForStorage({
    required CotsDetectionResult detection,
    required int? imageWidth,
    required int? imageHeight,
  }) {
    if (detection.count <= 0) return const [];

    if (detection.boxes.isNotEmpty) return detection.boxes;

    return CotsConfidencePolicy.syntheticBoundingBoxes(
      count: detection.count,
      imageWidth: imageWidth ?? 1920,
      imageHeight: imageHeight ?? 1080,
      averagePercent:
          CotsConfidencePolicy.percentFromConfidence(detection.confidence),
    );
  }
}
