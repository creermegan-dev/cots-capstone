import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/activity_type.dart';
import '../models/cots_detection_result.dart';
import 'cots_size_estimator.dart';
import 'zone_assignment_service.dart';

/// Persists citizen science GoPro scan submissions to Firestore.
abstract final class ScanRecordService {
  static Future<void> submit({
    required String uid,
    required String submittedBy,
    required String imageName,
    required String imagePath,
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
  }) async {
    final zone = ZoneAssignmentService.assignZone(
      latitude: latitude,
      longitude: longitude,
    );

    final data = <String, dynamic>{
      'uid': uid,
      'submitted_by': submittedBy,
      'image_name': imageName,
      'image_path': imagePath,
      'activity_type': activityType,
      'ai_detected_count': detection.count,
      'cots_count': detection.count,
      'confidence': detection.confidence,
      'capture_source': CaptureSource.goProUnderwaterImage,
      'citizen_contribution': true,
      'notes': notes,
      'zone': zone,
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

    if (CotsActivityType.isRemoval(activityType)) {
      data['confirmed_removed_quantity'] = confirmedRemovedQuantity;
    }
    if (measurementReferenceVisible != null) {
      data['measurement_reference_visible'] = measurementReferenceVisible;
    }
    if (removalMethod != null && removalMethod.isNotEmpty) {
      data['removal_method'] = removalMethod;
    }
    if (sizeEstimate != null) {
      data['average_size_cm'] = sizeEstimate.averageCm;
      data['minimum_size_cm'] = sizeEstimate.minimumCm;
      data['maximum_size_cm'] = sizeEstimate.maximumCm;
      data['size_confidence_score'] = sizeEstimate.confidenceScore;
      data['estimated_sizes_cm'] = sizeEstimate.perCotsCm;
    }

    await FirebaseFirestore.instance.collection('scan_records').add(data);
  }
}
