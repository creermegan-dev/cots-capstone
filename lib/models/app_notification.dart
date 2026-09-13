import 'package:cloud_firestore/cloud_firestore.dart';

/// A workflow event shown to one COTS Monitor user.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientUid,
    required this.type,
    required this.title,
    required this.body,
    required this.relatedRecordId,
    required this.zone,
    required this.dueAt,
    required this.createdAt,
    required this.isRead,
  });

  static const scanSubmitted = 'scan_submitted';
  static const reviewAccepted = 'review_accepted';
  static const reviewRejected = 'review_rejected';
  static const interventionAssigned = 'intervention_assigned';

  final String id;
  final String recipientUid;
  final String type;
  final String title;
  final String body;
  final String relatedRecordId;
  final String zone;
  final DateTime? dueAt;
  final DateTime? createdAt;
  final bool isRead;

  factory AppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      recipientUid: data['recipient_uid'] as String? ?? '',
      type: data['type'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      relatedRecordId: data['related_record_id'] as String? ?? '',
      zone: data['zone'] as String? ?? '',
      dueAt: _asDateTime(data['due_at']),
      createdAt: _asDateTime(data['created_at']),
      isRead: data['is_read'] == true,
    );
  }

  factory AppNotification.fromRestDocument(Map<String, dynamic> document) {
    final fields = (document['fields'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final name = document['name'] as String? ?? '';
    return AppNotification(
      id: name.split('/').last,
      recipientUid: _readString(fields, 'recipient_uid'),
      type: _readString(fields, 'type'),
      title: _readString(fields, 'title'),
      body: _readString(fields, 'body'),
      relatedRecordId: _readString(fields, 'related_record_id'),
      zone: _readString(fields, 'zone'),
      dueAt: _readTimestamp(fields, 'due_at'),
      createdAt: _readTimestamp(fields, 'created_at'),
      isRead: _readBool(fields, 'is_read'),
    );
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _readString(Map<String, dynamic> fields, String key) =>
      (fields[key] as Map?)?['stringValue'] as String? ?? '';

  static bool _readBool(Map<String, dynamic> fields, String key) =>
      (fields[key] as Map?)?['booleanValue'] == true;

  static DateTime? _readTimestamp(Map<String, dynamic> fields, String key) {
    final value = (fields[key] as Map?)?['timestampValue'] as String?;
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }
}
