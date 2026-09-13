import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../features/admin/models/admin_record_table_row.dart';
import 'activity_type.dart';
import 'capture_model.dart';
import 'cots_confidence_policy.dart';
import 'cots_detection_result.dart';
import 'record_collection.dart';
import 'removal_record_model.dart';
import '../utils/scan_record_image.dart';

/// Firestore `scan_records/{id}` citizen science submission.
class ScanRecordModel {
  const ScanRecordModel({
    required this.id,
    required this.uid,
    required this.submittedBy,
    required this.imageName,
    required this.imagePath,
    this.imageUrl = '',
    this.storageObjectPath = '',
    required this.activityType,
    required this.aiDetectedCount,
    required this.confidence,
    required this.captureSource,
    required this.zone,
    required this.notes,
    required this.submittedAt,
    this.dateTaken,
    this.latitude,
    this.longitude,
    this.removedQuantity,
    this.averageSizeCm,
    this.detectionBoxes = const [],
    this.imageWidth = 0,
    this.imageHeight = 0,
    this.adminConfirmed = false,
    this.adminRejected = false,
    this.adminReviewedBy = '',
    this.adminReviewedAt,
    this.adminCotsDecisions = const [],
    this.storedDisplayRecordId = '',
    this.recordCollection = RecordCollection.legacyScanRecords,
    this.linkedCaptureId,
    this.linkedCaptureDisplayId,
  });

  final String id;
  final String uid;
  final String submittedBy;
  final String imageName;
  final String imagePath;
  final String imageUrl;
  final String storageObjectPath;
  final String activityType;
  final int aiDetectedCount;
  final double confidence;
  final String captureSource;
  final String zone;
  final String notes;
  final DateTime? submittedAt;
  final DateTime? dateTaken;
  final double? latitude;
  final double? longitude;
  final int? removedQuantity;
  final double? averageSizeCm;
  final List<CotsBoundingBox> detectionBoxes;
  final int imageWidth;
  final int imageHeight;
  final bool adminConfirmed;
  final bool adminRejected;
  final String adminReviewedBy;
  final DateTime? adminReviewedAt;
  final List<PerCotsAdminDecision> adminCotsDecisions;
  final String storedDisplayRecordId;
  final String recordCollection;
  final String? linkedCaptureId;
  final String? linkedCaptureDisplayId;

  /// Parses a Firestore REST API document (`fields` map).
  factory ScanRecordModel.fromRestDocument(Map<String, dynamic> doc) {
    final name = doc['name'] as String? ?? '';
    final id = name.split('/').isNotEmpty ? name.split('/').last : '';
    final fields = doc['fields'] as Map<String, dynamic>? ?? {};
    return ScanRecordModel.fromRestFields(fields, id: id);
  }

  factory ScanRecordModel.fromRestFields(
    Map<String, dynamic> fields, {
    required String id,
  }) {
    final gps = _readMap(fields, 'gps');
    final resolution = _readMap(fields, 'resolution');
    return ScanRecordModel(
      id: id,
      uid: _readString(fields, 'uid'),
      submittedBy: _readString(fields, 'submitted_by', fallback: 'Unknown'),
      imageName: _readString(fields, 'image_name'),
      imagePath: _readString(fields, 'image_path'),
      imageUrl: _readString(fields, 'image_url'),
      storageObjectPath: _readString(fields, 'storage_object_path'),
      activityType: _readString(
        fields,
        'activity_type',
        fallback: CotsActivityType.detectionOnly,
      ),
      aiDetectedCount: _readInt(fields, 'ai_detected_count') != 0
          ? _readInt(fields, 'ai_detected_count')
          : _readInt(fields, 'cots_count'),
      confidence: _readDouble(fields, 'confidence') ?? 0,
      captureSource: _readString(
        fields,
        'capture_source',
        fallback: CaptureSource.goProUnderwaterImage,
      ),
      zone: _readString(fields, 'zone', fallback: 'Unassigned'),
      notes: _readString(fields, 'notes'),
      submittedAt: _readTimestamp(fields, 'submitted_at'),
      dateTaken: _readTimestamp(fields, 'date_taken'),
      latitude: _readDouble(gps, 'latitude'),
      longitude: _readDouble(gps, 'longitude'),
      removedQuantity: _readInt(fields, 'confirmed_removed_quantity'),
      averageSizeCm: _readDouble(fields, 'average_size_cm'),
      detectionBoxes: _readDetectionBoxes(fields),
      imageWidth: _readInt(resolution, 'width'),
      imageHeight: _readInt(resolution, 'height'),
      adminConfirmed: _readBool(fields, 'admin_confirmed'),
      adminRejected: _readBool(fields, 'admin_rejected'),
      adminReviewedBy: _readString(fields, 'admin_reviewed_by'),
      adminReviewedAt: _readTimestamp(fields, 'admin_reviewed_at'),
      adminCotsDecisions: PerCotsAdminDecisionX.listFromStorage(
        _readStringList(fields, 'admin_cots_decisions'),
      ),
      storedDisplayRecordId: _readString(fields, 'display_record_id'),
    );
  }

  factory ScanRecordModel.fromCapture(CaptureModel capture) {
    return ScanRecordModel(
      id: capture.id,
      uid: capture.uid,
      submittedBy: capture.submittedBy,
      imageName: capture.imageName,
      imagePath: '',
      activityType: CotsActivityType.detectionOnly,
      aiDetectedCount: capture.aiDetectedCount,
      confidence: capture.confidence,
      captureSource: capture.captureSource,
      zone: capture.zone,
      notes: capture.notes,
      submittedAt: capture.submittedAt,
      dateTaken: capture.dateTaken,
      latitude: capture.latitude,
      longitude: capture.longitude,
      averageSizeCm: capture.averageSizeCm,
      detectionBoxes: capture.detectionBoxes,
      imageWidth: capture.imageWidth,
      imageHeight: capture.imageHeight,
      adminConfirmed: capture.adminConfirmed,
      adminRejected: capture.adminRejected,
      adminReviewedBy: capture.adminReviewedBy,
      adminReviewedAt: capture.adminReviewedAt,
      adminCotsDecisions: capture.adminCotsDecisions,
      storedDisplayRecordId: capture.storedDisplayRecordId,
      recordCollection: RecordCollection.captures,
    );
  }

  factory ScanRecordModel.fromRemovalRecord(RemovalRecordModel removal) {
    return ScanRecordModel(
      id: removal.id,
      uid: removal.uid,
      submittedBy: removal.submittedBy,
      imageName: removal.imageName,
      imagePath: '',
      activityType: CotsActivityType.removalActivity,
      aiDetectedCount:
          removal.linkedCaptureAiCount ?? removal.aiVerifiedCount ?? 0,
      confidence: removal.aiConfidence ?? 0,
      captureSource: CaptureSource.goProUnderwaterImage,
      zone: removal.zone,
      notes: removal.notes,
      submittedAt: removal.submittedAt,
      dateTaken: removal.dateTaken,
      latitude: removal.latitude,
      longitude: removal.longitude,
      removedQuantity: removal.removedQuantity,
      detectionBoxes: const [],
      adminConfirmed: false,
      adminRejected: false,
      storedDisplayRecordId: removal.storedDisplayRecordId,
      recordCollection: RecordCollection.removalRecords,
      linkedCaptureId: removal.captureId,
      linkedCaptureDisplayId: removal.linkedCaptureDisplayId.isNotEmpty
          ? removal.linkedCaptureDisplayId
          : null,
    );
  }

  factory ScanRecordModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final gps = data['gps'];
    double? lat;
    double? lng;
    if (gps is Map) {
      lat = _asDouble(gps['latitude']);
      lng = _asDouble(gps['longitude']);
    }
    final resolution = data['resolution'];

    return ScanRecordModel(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      submittedBy: data['submitted_by'] as String? ?? 'Unknown',
      imageName: data['image_name'] as String? ?? '',
      imagePath: data['image_path'] as String? ?? '',
      imageUrl: data['image_url'] as String? ?? '',
      storageObjectPath: data['storage_object_path'] as String? ?? '',
      activityType: data['activity_type'] as String? ?? CotsActivityType.detectionOnly,
      aiDetectedCount: _asInt(data['ai_detected_count'] ?? data['cots_count']),
      confidence: _asDouble(data['confidence']) ?? 0,
      captureSource:
          data['capture_source'] as String? ?? CaptureSource.goProUnderwaterImage,
      zone: data['zone'] as String? ?? 'Unassigned',
      notes: data['notes'] as String? ?? '',
      submittedAt: _asDateTime(data['submitted_at']),
      dateTaken: _asDateTime(data['date_taken']),
      latitude: lat,
      longitude: lng,
      removedQuantity: _asInt(data['confirmed_removed_quantity']),
      averageSizeCm: _asDouble(data['average_size_cm']),
      detectionBoxes: CotsBoundingBox.listFromDynamic(data['detections']),
      imageWidth: resolution is Map ? _asInt(resolution['width']) : 0,
      imageHeight: resolution is Map ? _asInt(resolution['height']) : 0,
      adminConfirmed: data['admin_confirmed'] == true,
      adminRejected: data['admin_rejected'] == true,
      adminReviewedBy: data['admin_reviewed_by'] as String? ?? '',
      adminReviewedAt: _asDateTime(data['admin_reviewed_at']),
      adminCotsDecisions: PerCotsAdminDecisionX.listFromStorage(
        data['admin_cots_decisions'],
      ),
      storedDisplayRecordId: data['display_record_id'] as String? ?? '',
    );
  }

  AdminRecordTableRow toAdminTableRow(int index) {
    final count = aiDetectedCount;
    final confidencePercent = (confidence.clamp(0.0, 1.0) * 100).round();
    final when = submittedAt ?? dateTaken ?? DateTime.now();
    final fmt = DateFormat('MMM d, yyyy h:mm a');

    return AdminRecordTableRow(
      index,
      displayRecordId,
      zone,
      fmt.format(when),
      count,
      _densityEstimate(count),
      _riskFromCount(count),
      submittedBy,
      confidencePercent,
      activityType: CotsActivityType.label(activityType),
      aiCount: count,
      removedQuantity: removedQuantity,
      averageSizeCm: averageSizeCm,
      captureSource: captureSource,
      documentId: id,
      imageName: imageName,
      notes: notes,
      dateCaptured: dateTaken != null ? fmt.format(dateTaken!) : 'Unknown',
      dateUploaded: submittedAt != null ? fmt.format(submittedAt!) : fmt.format(when),
      latitude: latitude,
      longitude: longitude,
      imagePath: imagePath,
      imageUrl: imageUrl,
      storageObjectPath: storageObjectPath,
      detectionBoxes: detectionBoxes,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      adminConfirmed: adminConfirmed,
      adminRejected: adminRejected,
      adminCotsDecisions: adminCotsDecisions,
      recordCollection: recordCollection,
      linkedCaptureId: linkedCaptureId,
      linkedCaptureDisplayId: linkedCaptureDisplayId,
      ownerUid: uid,
    );
  }

  String? get submittedImageUrl =>
      ScanRecordImage.networkUrl(imageUrl: imageUrl, imagePath: imagePath);

  bool get hasLocalSubmittedImage =>
      ScanRecordImage.hasReadableLocalFile(imagePath);

  String get displayRecordId => storedDisplayRecordId.isNotEmpty
      ? storedDisplayRecordId
      : formatDisplayRecordId(id);

  /// User-facing ID stored in Firestore as `display_record_id` (e.g. REC-A1B2C3D4).
  static String formatDisplayRecordId(String documentId) =>
      _displayRecordId(documentId);

  /// New Firestore document id before create (same format as auto-generated ids).
  static String newDocumentId() =>
      FirebaseFirestore.instance.collection('scan_records').doc().id;

  int get confidencePercent => CotsConfidencePolicy.percentFromConfidence(confidence);

  List<CotsDetectionReviewItem> get detectionReviewItems =>
      CotsConfidencePolicy.buildDetectionItems(
        count: aiDetectedCount,
        averagePercent: confidencePercent,
        boxes: detectionBoxes.isNotEmpty ? detectionBoxes : null,
        imageWidth: imageWidth > 0 ? imageWidth : 1920,
        imageHeight: imageHeight > 0 ? imageHeight : 1080,
      );

  String get userStatusLabel {
    if (CotsActivityType.isRemoval(activityType)) {
      if (adminConfirmed) return 'Verified';
      if (adminRejected) return 'Rejected';
      return 'Pending Verification';
    }
    return CotsConfidencePolicy.userStatusLabelFromItems(
      detectionReviewItems,
      adminConfirmed: adminConfirmed,
      adminRejected: adminRejected,
    );
  }

  String get userStatusDescription {
    if (CotsActivityType.isRemoval(activityType)) {
      if (adminConfirmed) {
        return 'Removal evidence was verified. This intervention record is closed.';
      }
      if (adminRejected) {
        return 'Removal evidence was rejected. Please resubmit clearer evidence.';
      }
      return 'Removal Status: Pending Verification. An expert will review this '
          'removal evidence before it is confirmed.';
    }
    return CotsConfidencePolicy.userStatusDescriptionFromItems(
      detectionReviewItems,
      adminConfirmed: adminConfirmed,
      adminRejected: adminRejected,
    );
  }

  bool get shouldRetakePhoto =>
      CotsConfidencePolicy.recordBandFromItems(detectionReviewItems) ==
      CotsVerificationBand.retakeRequired;

  String get formattedCoordinates {
    if (latitude == null || longitude == null) return 'Unknown';
    final lat = latitude!;
    final lng = longitude!;
    return '${lat.abs().toStringAsFixed(6)}° ${lat >= 0 ? 'N' : 'S'}, '
        '${lng.abs().toStringAsFixed(6)}° ${lng >= 0 ? 'E' : 'W'}';
  }

  static String _displayRecordId(String docId) {
    if (docId.length <= 10) return 'REC-$docId'.toUpperCase();
    return 'REC-${docId.substring(0, 8).toUpperCase()}';
  }

  static double _densityEstimate(int count) =>
      count <= 0 ? 0 : (count * 14.25).clamp(0, 999);

  static String _riskFromCount(int count) {
    if (count >= 20) return 'High';
    if (count >= 5) return 'Moderate';
    return 'Low';
  }

  /// Maps submission count to the user records page status labels.
  static String userStatusFromCount(int count) {
    if (count >= 15) return 'Active';
    if (count >= 5) return 'Scheduled';
    return 'Cleared';
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return 0;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return null;
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static bool _readBool(Map<String, dynamic> fields, String key) {
    final v = fields[key];
    if (v is Map && v['booleanValue'] != null) {
      return v['booleanValue'] == true;
    }
    return false;
  }

  static List<String> _readStringList(Map<String, dynamic> fields, String key) {
    final v = fields[key];
    if (v is Map && v['arrayValue'] is Map) {
      final values = (v['arrayValue'] as Map)['values'];
      if (values is List) {
        return [
          for (final item in values)
            if (item is Map && item['stringValue'] != null)
              item['stringValue'].toString(),
        ];
      }
    }
    return const [];
  }

  static String _readString(
    Map<String, dynamic> fields,
    String key, {
    String fallback = '',
  }) {
    final v = fields[key];
    if (v is Map && v['stringValue'] != null) {
      return v['stringValue'].toString();
    }
    return fallback;
  }

  static int _readInt(Map<String, dynamic> fields, String key) {
    final v = fields[key];
    if (v is Map) {
      if (v['integerValue'] != null) {
        return int.tryParse(v['integerValue'].toString()) ?? 0;
      }
      if (v['doubleValue'] != null) {
        return (v['doubleValue'] as num).round();
      }
    }
    return 0;
  }

  static double? _readDouble(Map<String, dynamic> fields, String key) {
    final v = fields[key];
    if (v is Map) {
      if (v['doubleValue'] != null) return (v['doubleValue'] as num).toDouble();
      if (v['integerValue'] != null) {
        return double.tryParse(v['integerValue'].toString());
      }
    }
    return null;
  }

  static DateTime? _readTimestamp(Map<String, dynamic> fields, String key) {
    final v = fields[key];
    if (v is Map && v['timestampValue'] is String) {
      return DateTime.tryParse(v['timestampValue'] as String);
    }
    return null;
  }

  static List<CotsBoundingBox> _readDetectionBoxes(Map<String, dynamic> fields) {
    final raw = fields['detections'];
    if (raw is Map && raw['arrayValue'] is Map) {
      final values = (raw['arrayValue'] as Map)['values'];
      if (values is List) {
        return [
          for (final v in values)
            if (v is Map && v['mapValue'] is Map)
              CotsBoundingBox.fromMap(
                _restMapFields(v['mapValue'] as Map),
              ),
        ];
      }
    }
    return const [];
  }

  static Map<String, dynamic> _restMapFields(Map map) {
    final fields = map['fields'];
    if (fields is! Map) return const {};
    final out = <String, dynamic>{};
    fields.forEach((key, value) {
      if (value is! Map) return;
      if (value['doubleValue'] != null) {
        out[key.toString()] = value['doubleValue'];
      } else if (value['integerValue'] != null) {
        out[key.toString()] = value['integerValue'];
      }
    });
    return out;
  }

  static Map<String, dynamic> _readMap(
    Map<String, dynamic> fields,
    String key,
  ) {
    final v = fields[key];
    if (v is Map && v['mapValue'] is Map) {
      final inner = v['mapValue'] as Map;
      if (inner['fields'] is Map<String, dynamic>) {
        return inner['fields'] as Map<String, dynamic>;
      }
    }
    return const {};
  }
}
