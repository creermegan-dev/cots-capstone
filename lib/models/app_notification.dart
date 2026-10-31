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
  static const reviewNeeded = 'review_needed';
  static const recordFinalized = 'record_finalized';
  static const recordRejected = 'record_rejected';
  static const followUpReassignment = 'follow_up_reassignment';

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

  /// Builds a notification from a Supabase `notifications` row with its
  /// `workflow_events` row embedded. The database stores the wording with the
  /// event, so every screen shows the same text.
  factory AppNotification.fromSupabase(Map<String, dynamic> row) {
    final event = _asMap(row['workflow_events']);
    final details = _asMap(event['details']);
    final requestId = _asText(event['request_id']);
    // Replacement notices open the request, as in the Firebase version.
    final type = requestId.isNotEmpty
        ? followUpReassignment
        : _asText(event['action']);
    final title = _asText(details['title']);
    return AppNotification(
      id: _asText(row['id']),
      recipientUid: _asText(row['recipient_id']),
      type: type,
      title: title.isNotEmpty ? title : titleForType(_asText(event['action'])),
      body: _asText(details['body']),
      relatedRecordId:
          requestId.isNotEmpty ? requestId : _asText(details['record_id']),
      zone: _asText(details['zone']),
      dueAt: _parseTime(details['due_at']),
      createdAt: _parseTime(row['created_at']) ?? _parseTime(event['created_at']),
      isRead: row['read_at'] != null,
    );
  }

  /// A readable title for events saved without one, e.g. 'request_created'
  /// becomes 'Request created'.
  static String titleForType(String type) {
    final words = type.replaceAll('_', ' ').trim();
    if (words.isEmpty) return 'Notification';
    return words[0].toUpperCase() + words.substring(1);
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return const <String, dynamic>{};
  }

  static String _asText(Object? value) => value == null ? '' : value.toString();

  static DateTime? _parseTime(Object? value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
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
