import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import '../models/app_notification.dart';
import '../models/record_collection.dart';
import 'windows_auth_rest_service.dart';

/// Firestore REST implementation for notifications on Windows.
class WindowsNotificationRestService {
  WindowsNotificationRestService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  static const _options = DefaultFirebaseOptions.windows;

  String get _base =>
      'https://firestore.googleapis.com/v1/projects/${_options.projectId}'
      '/databases/(default)/documents';

  Future<List<AppNotification>> queryForUser({
    required String idToken,
    required String uid,
  }) async {
    final response = await _client.post(
      Uri.parse('$_base:runQuery'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'structuredQuery': {
          'from': [
            {'collectionId': RecordCollection.notifications},
          ],
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': 'recipient_uid'},
              'op': 'EQUAL',
              'value': {'stringValue': uid},
            },
          },
        },
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsAuthRestException(
        'Could not load notifications (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    final notifications = <AppNotification>[];
    for (final row in decoded) {
      if (row is! Map<String, dynamic>) continue;
      final document = row['document'];
      if (document is Map<String, dynamic>) {
        notifications.add(AppNotification.fromRestDocument(document));
      }
    }
    return notifications;
  }

  Stream<List<AppNotification>> watchForUser({
    required String idToken,
    required String uid,
  }) async* {
    yield await queryForUser(idToken: idToken, uid: uid);
    yield* Stream.periodic(const Duration(seconds: 15)).asyncMap(
      (_) => queryForUser(idToken: idToken, uid: uid),
    );
  }

  Future<void> create({
    required String idToken,
    required String recipientUid,
    required String type,
    required String title,
    required String body,
    required String relatedRecordId,
    required String zone,
    DateTime? dueAt,
  }) async {
    final fields = <String, dynamic>{
      'recipient_uid': _string(recipientUid),
      'type': _string(type),
      'title': _string(title),
      'body': _string(body),
      'related_record_id': _string(relatedRecordId),
      'zone': _string(zone),
      'is_read': _bool(false),
      'created_at': _timestamp(DateTime.now().toUtc().toIso8601String()),
    };
    if (dueAt != null) {
      fields['due_at'] = _timestamp(dueAt.toUtc().toIso8601String());
    }
    final response = await _client.post(
      Uri.parse('$_base/${RecordCollection.notifications}'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'fields': fields}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsAuthRestException(
        'Could not create notification (${response.statusCode}).',
      );
    }
  }

  Future<void> markRead({
    required String idToken,
    required String notificationId,
  }) => _patch(
        idToken: idToken,
        notificationId: notificationId,
        fields: {'is_read': _bool(true)},
      );

  Future<void> delete({
    required String idToken,
    required String notificationId,
  }) async {
    final response = await _client.delete(
      Uri.parse('$_base/${RecordCollection.notifications}/$notificationId'),
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsAuthRestException(
        'Could not clear notification (${response.statusCode}).',
      );
    }
  }

  Future<void> _patch({
    required String idToken,
    required String notificationId,
    required Map<String, dynamic> fields,
  }) async {
    final mask = fields.keys
        .map((key) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(key)}')
        .join('&');
    final response = await _client.patch(
      Uri.parse('$_base/${RecordCollection.notifications}/$notificationId?$mask'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'fields': fields}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsAuthRestException(
        'Could not update notification (${response.statusCode}).',
      );
    }
  }

  Map<String, dynamic> _string(String value) => {'stringValue': value};
  Map<String, dynamic> _bool(bool value) => {'booleanValue': value};
  Map<String, dynamic> _timestamp(String value) => {'timestampValue': value};
}
