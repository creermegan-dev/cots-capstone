import 'dart:convert';

import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import '../models/admin_preferences.dart';
import 'windows_auth_rest_service.dart';

class WindowsAdminPreferencesRestService {
  WindowsAdminPreferencesRestService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  static const _options = DefaultFirebaseOptions.windows;

  String get _base =>
      'https://firestore.googleapis.com/v1/projects/${_options.projectId}'
      '/databases/(default)/documents/admin_preferences';

  Future<AdminPreferences> load({
    required String uid,
    required String idToken,
  }) async {
    final response = await _client.get(
      Uri.parse('$_base/$uid'),
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (response.statusCode == 404) return AdminPreferences.defaults(uid);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsAuthRestException(
        'Could not load administrator preferences (${response.statusCode}).',
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const WindowsAuthRestException(
        'Administrator preferences returned an invalid response.',
      );
    }
    return AdminPreferences.fromRestDocument(uid, body);
  }

  Future<void> save({
    required AdminPreferences preferences,
    required String idToken,
  }) async {
    final fields = <String, dynamic>{};
    for (final entry in preferences.toMap().entries) {
      fields[entry.key] = entry.value is bool
          ? {'booleanValue': entry.value}
          : {'stringValue': entry.value};
    }
    final mask = AdminPreferences.fields
        .map((field) =>
            'updateMask.fieldPaths=${Uri.encodeQueryComponent(field)}')
        .join('&');
    final response = await _client.patch(
      Uri.parse('$_base/${preferences.uid}?$mask'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'fields': fields}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsAuthRestException(
        'Could not save administrator preferences (${response.statusCode}).',
      );
    }
  }
}
