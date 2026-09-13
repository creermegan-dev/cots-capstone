import 'package:cloud_firestore/cloud_firestore.dart';

/// Operational assignment for a validated COTS detection.
///
/// Documents use the capture ID as their ID so one capture has one active
/// intervention assignment while its detection and removal history stay intact.
class InterventionAssignmentModel {
  const InterventionAssignmentModel({
    required this.captureId,
    required this.captureDisplayId,
    required this.zone,
    required this.assignedToUid,
    required this.assignedToName,
    required this.assignedByUid,
    required this.assignedByName,
    required this.status,
    this.assignedAt,
    this.dueAt,
    this.evidenceSubmittedAt,
    this.removalRecordId = '',
  });

  static const assignedStatus = 'assigned';
  static const evidenceSubmittedStatus = 'evidence_submitted';
  static const clearedStatus = 'cleared';

  final String captureId;
  final String captureDisplayId;
  final String zone;
  final String assignedToUid;
  final String assignedToName;
  final String assignedByUid;
  final String assignedByName;
  final String status;
  final DateTime? assignedAt;
  final DateTime? dueAt;
  final DateTime? evidenceSubmittedAt;
  final String removalRecordId;

  bool get isOpen => status == assignedStatus;
  bool get hasEvidence => status == evidenceSubmittedStatus;
  bool get isCleared => status == clearedStatus;

  factory InterventionAssignmentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return InterventionAssignmentModel.fromMap(
      doc.data() ?? const {},
      captureId: doc.id,
    );
  }

  factory InterventionAssignmentModel.fromMap(
    Map<String, dynamic> map, {
    required String captureId,
  }) {
    return InterventionAssignmentModel(
      captureId: (map['capture_id'] as String?)?.trim().isNotEmpty == true
          ? map['capture_id'] as String
          : captureId,
      captureDisplayId: map['capture_display_id'] as String? ?? '',
      zone: map['zone'] as String? ?? 'Unassigned',
      assignedToUid: map['assigned_to_uid'] as String? ?? '',
      assignedToName: map['assigned_to_name'] as String? ?? '',
      assignedByUid: map['assigned_by_uid'] as String? ?? '',
      assignedByName: map['assigned_by_name'] as String? ?? '',
      status: map['status'] as String? ?? assignedStatus,
      assignedAt: _asDateTime(map['assigned_at']),
      dueAt: _asDateTime(map['due_at']),
      evidenceSubmittedAt: _asDateTime(map['evidence_submitted_at']),
      removalRecordId: map['removal_record_id'] as String? ?? '',
    );
  }

  factory InterventionAssignmentModel.fromRestDocument(
    Map<String, dynamic> doc,
  ) {
    final name = doc['name'] as String? ?? '';
    final id = name.split('/').isNotEmpty ? name.split('/').last : '';
    final fields = doc['fields'] as Map<String, dynamic>? ?? const {};
    return InterventionAssignmentModel(
      captureId: _readString(fields, 'capture_id', fallback: id),
      captureDisplayId: _readString(fields, 'capture_display_id'),
      zone: _readString(fields, 'zone', fallback: 'Unassigned'),
      assignedToUid: _readString(fields, 'assigned_to_uid'),
      assignedToName: _readString(fields, 'assigned_to_name'),
      assignedByUid: _readString(fields, 'assigned_by_uid'),
      assignedByName: _readString(fields, 'assigned_by_name'),
      status: _readString(
        fields,
        'status',
        fallback: assignedStatus,
      ),
      assignedAt: _readTimestamp(fields, 'assigned_at'),
      dueAt: _readTimestamp(fields, 'due_at'),
      evidenceSubmittedAt: _readTimestamp(fields, 'evidence_submitted_at'),
      removalRecordId: _readString(fields, 'removal_record_id'),
    );
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String _readString(
    Map<String, dynamic> fields,
    String key, {
    String fallback = '',
  }) {
    final value = fields[key];
    if (value is Map && value['stringValue'] != null) {
      return value['stringValue'].toString();
    }
    return fallback;
  }

  static DateTime? _readTimestamp(
    Map<String, dynamic> fields,
    String key,
  ) {
    final value = fields[key];
    if (value is Map && value['timestampValue'] is String) {
      return DateTime.tryParse(value['timestampValue'] as String);
    }
    return null;
  }
}
