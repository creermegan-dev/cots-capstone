import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import '../models/user_model.dart';
import 'windows_auth_rest_service.dart';

/// Admin personnel-directory operations over Firestore REST on Windows.
class WindowsPersonnelRestService {
  WindowsPersonnelRestService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  static const _options = DefaultFirebaseOptions.windows;

  Future<List<UserModel>> queryUsers({required String idToken}) async {
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/${_options.projectId}'
      '/databases/(default)/documents:runQuery',
    );
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'structuredQuery': {
          'from': [
            {'collectionId': 'users'},
          ],
        },
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsAuthRestException(
        'Could not load the personnel directory (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    final users = <UserModel>[];
    for (final row in decoded) {
      if (row is! Map<String, dynamic>) continue;
      final doc = row['document'];
      if (doc is Map<String, dynamic>) {
        users.add(UserModel.fromRestDocument(doc));
      }
    }
    users.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return users;
  }

  Stream<List<UserModel>> watchUsers({required String idToken}) async* {
    yield await queryUsers(idToken: idToken);
    yield* Stream.periodic(const Duration(seconds: 15))
        .asyncMap((_) => queryUsers(idToken: idToken));
  }

  Future<void> setPersonnelVerification({
    required String idToken,
    required String userId,
    required bool verified,
    required String verifiedBy,
  }) async {
    const fields = [
      'fieldPersonnelVerified',
      'personnelVerifiedBy',
      'personnelVerifiedAt',
    ];
    final mask = fields
        .map((f) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(f)}')
        .join('&');
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/${_options.projectId}'
      '/databases/(default)/documents/users/$userId?$mask',
    );
    final now = DateTime.now().toUtc().toIso8601String();
    final response = await _client.patch(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'fields': {
          'fieldPersonnelVerified': {'booleanValue': verified},
          'personnelVerifiedBy': {'stringValue': verified ? verifiedBy : ''},
          'personnelVerifiedAt': {'timestampValue': now},
        },
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsAuthRestException(
        'Could not update personnel verification (${response.statusCode}).',
      );
    }
  }
}
