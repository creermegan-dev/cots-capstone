import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../features/admin/models/admin_record_table_row.dart';
import 'activity_type.dart';
import 'record_collection.dart';

/// Removal activity linked to a capture via `capture_id` in `removal_records/{id}`.
class RemovalRecordModel {
  const RemovalRecordModel({
    required this.id,
    required this.captureId,
    required this.uid,
    required this.submittedBy,
    required this.imageName,
    required this.removedQuantity,
    required this.removalMethod,
    required this.zone,
    required this.notes,
    required this.submittedAt,
    this.dateTaken,
    this.latitude,
    this.longitude,
    this.aiVerifiedCount,
    this.aiConfidence,
    this.linkedCaptureDisplayId = '',
    this.linkedCaptureAiCount,
    this.storedDisplayRecordId = '',
  });

  final String id;
  final String captureId;
  final String uid;
  final String submittedBy;
  final String imageName;
  final int removedQuantity;
  final String removalMethod;
  final String zone;
  final String notes;
  final DateTime? submittedAt;
  final DateTime? dateTaken;
  final double? latitude;
  final double? longitude;
  final int? aiVerifiedCount;
  final double? aiConfidence;
  final String linkedCaptureDisplayId;
  final int? linkedCaptureAiCount;
  final String storedDisplayRecordId;

  factory RemovalRecordModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    CaptureLink? captureLink,
  }) {
    final data = doc.data() ?? {};
    final gps = data['gps'];
    double? lat;
    double? lng;
    if (gps is Map) {
      lat = _asDouble(gps['latitude']);
      lng = _asDouble(gps['longitude']);
    }

    return RemovalRecordModel(
      id: doc.id,
      captureId: data['capture_id'] as String? ?? '',
      uid: data['uid'] as String? ?? '',
      submittedBy: data['submitted_by'] as String? ?? 'Unknown',
      imageName: data['image_name'] as String? ?? '',
      removedQuantity: _asInt(data['removed_quantity']),
      removalMethod: data['removal_method'] as String? ?? '',
      zone: data['zone'] as String? ?? 'Unassigned',
      notes: data['notes'] as String? ?? '',
      submittedAt: _asDateTime(data['submitted_at']),
      dateTaken: _asDateTime(data['date_taken']),
      latitude: lat,
      longitude: lng,
      aiVerifiedCount: data['ai_verified_count'] == null
          ? null
          : _asInt(data['ai_verified_count']),
      aiConfidence: _asDouble(data['ai_confidence']),
      linkedCaptureDisplayId: captureLink?.displayId ?? '',
      linkedCaptureAiCount: captureLink?.aiCount,
      storedDisplayRecordId: data['display_record_id'] as String? ?? '',
    );
  }

  factory RemovalRecordModel.fromRestDocument(
    Map<String, dynamic> doc, {
    CaptureLink? captureLink,
  }) {
    final name = doc['name'] as String? ?? '';
    final id = name.split('/').isNotEmpty ? name.split('/').last : '';
    final fields = doc['fields'] as Map<String, dynamic>? ?? {};
    return RemovalRecordModel.fromRestFields(
      fields,
      id: id,
      captureLink: captureLink,
    );
  }

  factory RemovalRecordModel.fromRestFields(
    Map<String, dynamic> fields, {
    required String id,
    CaptureLink? captureLink,
  }) {
    final gps = _readMap(fields, 'gps');
    return RemovalRecordModel(
      id: id,
      captureId: _readString(fields, 'capture_id'),
      uid: _readString(fields, 'uid'),
      submittedBy: _readString(fields, 'submitted_by', fallback: 'Unknown'),
      imageName: _readString(fields, 'image_name'),
      removedQuantity: _readInt(fields, 'removed_quantity'),
      removalMethod: _readString(fields, 'removal_method'),
      zone: _readString(fields, 'zone', fallback: 'Unassigned'),
      notes: _readString(fields, 'notes'),
      submittedAt: _readTimestamp(fields, 'submitted_at'),
      dateTaken: _readTimestamp(fields, 'date_taken'),
      latitude: _readDouble(gps, 'latitude'),
      longitude: _readDouble(gps, 'longitude'),
      aiVerifiedCount: fields.containsKey('ai_verified_count')
          ? _readInt(fields, 'ai_verified_count')
          : null,
      aiConfidence: _readDouble(fields, 'ai_confidence'),
      linkedCaptureDisplayId: captureLink?.displayId ?? '',
      linkedCaptureAiCount: captureLink?.aiCount,
      storedDisplayRecordId: _readString(fields, 'display_record_id'),
    );
  }

  String get displayRecordId => storedDisplayRecordId.isNotEmpty
      ? storedDisplayRecordId
      : formatDisplayRecordId(id);

  static String formatDisplayRecordId(String documentId) {
    if (documentId.length <= 10) return 'REM-$documentId'.toUpperCase();
    return 'REM-${documentId.substring(0, 8).toUpperCase()}';
  }

  static String newDocumentId() => FirebaseFirestore.instance
      .collection(RecordCollection.removalRecords)
      .doc()
      .id;

  AdminRecordTableRow toAdminTableRow(int index) {
    final when = submittedAt ?? dateTaken ?? DateTime.now();
    final fmt = DateFormat('MMM d, yyyy h:mm a');
    final aiCount = linkedCaptureAiCount ?? aiVerifiedCount ?? removedQuantity;

    return AdminRecordTableRow(
      index,
      displayRecordId,
      zone,
      fmt.format(when),
      removedQuantity,
      _densityEstimate(removedQuantity),
      _riskFromCount(removedQuantity),
      submittedBy,
      aiConfidence != null ? (aiConfidence! * 100).round() : 0,
      activityType: CotsActivityType.label(CotsActivityType.removalActivity),
      aiCount: aiCount,
      removedQuantity: removedQuantity,
      captureSource: CaptureSource.goProUnderwaterImage,
      documentId: id,
      imageName: imageName,
      notes: notes,
      dateCaptured: dateTaken != null ? fmt.format(dateTaken!) : 'Unknown',
      dateUploaded: submittedAt != null ? fmt.format(submittedAt!) : fmt.format(when),
      latitude: latitude,
      longitude: longitude,
      recordCollection: RecordCollection.removalRecords,
      linkedCaptureId: captureId,
      linkedCaptureDisplayId: linkedCaptureDisplayId,
      ownerUid: uid,
    );
  }

  static double _densityEstimate(int count) =>
      count <= 0 ? 0 : (count * 14.25).clamp(0, 999);

  static String _riskFromCount(int count) {
    if (count >= 20) return 'High';
    if (count >= 5) return 'Moderate';
    return 'Low';
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

/// Lightweight capture reference for removal record joins.
class CaptureLink {
  const CaptureLink({
    required this.id,
    required this.displayId,
    required this.aiCount,
    required this.zone,
  });

  final String id;
  final String displayId;
  final int aiCount;
  final String zone;
}
