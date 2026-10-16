import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../core/firebase_bootstrap.dart';
import '../firebase_options.dart';
import 'scan_record_repository.dart';

/// Authenticated REST commits work on native Firebase and Windows alike.
/// Update-time preconditions make stale proposals/responses fail atomically.
class FollowUpWorkflowStore {
  FollowUpWorkflowStore(
      {http.Client? client,
      String? projectId,
      Future<String?> Function()? tokenProvider})
      : _client = client ?? http.Client(),
        _projectId = projectId,
        _tokenProvider = tokenProvider;
  final http.Client _client;
  final String? _projectId;
  final Future<String?> Function()? _tokenProvider;
  String get root =>
      'projects/${_projectId ?? DefaultFirebaseOptions.currentPlatform.projectId}'
      '/databases/(default)/documents';
  Future<Map<String, String>> _headers() async {
    final token = _tokenProvider != null
        ? await _tokenProvider!()
        : deferFirebaseUntilFirstUse
            ? ScanRecordRepository.windowsIdToken
            : await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) {
      throw StateError('Sign in to access follow-up assignments.');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json'
    };
  }

  Future<Map<String, dynamic>?> get(String path) async {
    final response = await _client.get(
        Uri.parse('https://firestore.googleapis.com/v1/$root/$path'),
        headers: await _headers());
    if (response.statusCode == 404) return null;
    _check(response);
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<List<Map<String, dynamic>>> query(String collection,
      {String? field, Object? value, String op = 'EQUAL'}) async {
    final response = await _client.post(
      Uri.parse('https://firestore.googleapis.com/v1/$root:runQuery'),
      headers: await _headers(),
      body: jsonEncode({
        'structuredQuery': {
          'from': [
            {'collectionId': collection}
          ],
          if (field != null)
            'where': {
              'fieldFilter': {
                'field': {'fieldPath': field},
                'op': op,
                'value': encode(value),
              }
            },
        }
      }),
    );
    _check(response);
    return (jsonDecode(response.body) as List)
        .whereType<Map>()
        .where((row) => row['document'] is Map)
        .map((row) => Map<String, dynamic>.from(row['document'] as Map))
        .toList();
  }

  Map<String, dynamic> write(String path, Map<String, dynamic> data,
          {Map<String, dynamic>? existing,
          bool create = false,
          List<String>? mask,
          List<String> serverTimes = const []}) =>
      {
        'update': {'name': '$root/$path', 'fields': fields(data)},
        if (mask != null) 'updateMask': {'fieldPaths': mask},
        if (create) 'currentDocument': {'exists': false},
        if (existing != null)
          'currentDocument': {'updateTime': existing['updateTime']},
        if (serverTimes.isNotEmpty)
          'updateTransforms': [
            for (final field in serverTimes)
              {'fieldPath': field, 'setToServerValue': 'REQUEST_TIME'},
          ],
      };

  Future<void> commit(List<Map<String, dynamic>> writes) async {
    final response = await _client.post(
      Uri.parse('https://firestore.googleapis.com/v1/$root:commit'),
      headers: await _headers(),
      body: jsonEncode({'writes': writes}),
    );
    _check(response);
  }

  static void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 409 || response.statusCode == 412) {
      throw StateError('This request changed. Refresh before trying again.');
    }
    throw StateError('Follow-up operation failed (${response.statusCode}). '
        'Check your permissions and connection, then retry.');
  }

  static Map<String, dynamic> fields(Map<String, dynamic> data) =>
      data.map((key, value) => MapEntry(key, encode(value)));
  static Map<String, dynamic> encode(Object? value) {
    if (value == null) return {'nullValue': null};
    if (value is String) return {'stringValue': value};
    if (value is bool) return {'booleanValue': value};
    if (value is int) return {'integerValue': '$value'};
    if (value is num) return {'doubleValue': value};
    if (value is DateTime) {
      return {'timestampValue': value.toUtc().toIso8601String()};
    }
    if (value is List) {
      return {
        'arrayValue': {'values': value.map(encode).toList()}
      };
    }
    if (value is Map<String, dynamic>) {
      return {
        'mapValue': {'fields': fields(value)}
      };
    }
    throw ArgumentError('Unsupported workflow value.');
  }

  static Map<String, dynamic> data(Map<String, dynamic> document) =>
      (document['fields'] as Map? ?? {})
          .map((key, value) => MapEntry(key as String, decode(value as Map)));
  static Object? decode(Map value) {
    if (value.containsKey('stringValue')) return value['stringValue'];
    if (value.containsKey('booleanValue')) return value['booleanValue'];
    if (value.containsKey('integerValue')) {
      return int.parse('${value['integerValue']}');
    }
    if (value.containsKey('doubleValue')) return value['doubleValue'];
    if (value.containsKey('timestampValue')) {
      return DateTime.parse(value['timestampValue'] as String);
    }
    if (value.containsKey('arrayValue')) {
      return ((value['arrayValue'] as Map)['values'] as List? ?? [])
          .map((v) => decode(v as Map))
          .toList();
    }
    if (value.containsKey('mapValue')) {
      return data(value['mapValue'] as Map<String, dynamic>);
    }
    return null;
  }
}
