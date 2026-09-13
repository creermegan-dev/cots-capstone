import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import '../models/user_model.dart';

/// Firebase Auth + Firestore over HTTPS for Windows desktop.
///
/// Avoids [firebase_auth] / [cloud_firestore] native plugins, which can crash the
/// Flutter Windows engine during login (EventChannel threading bug).
class WindowsAuthRestService {
  WindowsAuthRestService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const _options = DefaultFirebaseOptions.windows;

  Future<WindowsAuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final body = await _postIdentity(
      'accounts:signInWithPassword',
      {
        'email': email.trim(),
        'password': password,
        'returnSecureToken': true,
      },
    );
    return _sessionFromIdentityResponse(body, email.trim());
  }

  Future<WindowsAuthSession> signUp({
    required String email,
    required String password,
  }) async {
    final body = await _postIdentity(
      'accounts:signUp',
      {
        'email': email.trim(),
        'password': password,
        'returnSecureToken': true,
      },
    );
    return _sessionFromIdentityResponse(body, email.trim());
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _postIdentity(
      'accounts:sendOobCode',
      {
        'requestType': 'PASSWORD_RESET',
        'email': email.trim(),
      },
    );
  }

  Future<UserModel?> fetchUserProfile({
    required String uid,
    required String idToken,
  }) async {
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/${_options.projectId}'
      '/databases/(default)/documents/users/$uid',
    );
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsAuthRestException(
        _messageForHttp('load profile', response),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return UserModel.fromRestDocument(decoded);
  }

  Future<void> createUserProfile({
    required UserModel model,
    required String idToken,
  }) async {
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/${_options.projectId}'
      '/databases/(default)/documents/users?documentId=${model.uid}',
    );
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'fields': _encodeUserFields(model, includeCreatedAt: true),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsAuthRestException(
        _messageForHttp('create profile', response),
      );
    }
  }

  Future<void> updateUserProfile({
    required String uid,
    required String idToken,
    required String fullName,
    required String phoneNumber,
    required String role,
    required String organization,
    required String assignedArea,
  }) async {
    const maskFields = [
      'fullName',
      'phoneNumber',
      'role',
      'organization',
      'assignedArea',
    ];
    final maskQuery = maskFields
        .map((f) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(f)}')
        .join('&');
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/${_options.projectId}'
      '/databases/(default)/documents/users/$uid?$maskQuery',
    );
    final response = await _client.patch(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'fields': {
          'fullName': {'stringValue': fullName.trim()},
          'phoneNumber': {'stringValue': phoneNumber.trim()},
          'role': {'stringValue': role.trim()},
          'organization': {'stringValue': organization.trim()},
          'assignedArea': {'stringValue': assignedArea.trim()},
        },
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsAuthRestException(
        _messageForHttp('update profile', response),
      );
    }
  }

  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    final session = await signIn(email: email, password: currentPassword);
    await _postIdentity(
      'accounts:update',
      {
        'idToken': session.idToken,
        'password': newPassword,
        'returnSecureToken': true,
      },
    );
  }

  Future<Map<String, dynamic>> _postIdentity(
    String method,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/$method?key=${_options.apiKey}',
    );
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded as Map<String, dynamic>;
    }
    if (decoded is Map<String, dynamic> && decoded['error'] is Map) {
      final err = decoded['error'] as Map<String, dynamic>;
      throw WindowsAuthRestException(
        _messageForIdentityError(err),
      );
    }
    throw WindowsAuthRestException(
      _messageForHttp('authentication', response),
    );
  }

  WindowsAuthSession _sessionFromIdentityResponse(
    Map<String, dynamic> body,
    String email,
  ) {
    final idToken = body['idToken'] as String?;
    final localId = body['localId'] as String?;
    if (idToken == null || localId == null) {
      throw const WindowsAuthRestException(
        'Authentication succeeded but no session token was returned.',
      );
    }
    return WindowsAuthSession(
      uid: localId,
      email: email,
      idToken: idToken,
    );
  }

  Map<String, dynamic> _encodeUserFields(
    UserModel model, {
    required bool includeCreatedAt,
  }) {
    final fields = <String, dynamic>{
      'uid': {'stringValue': model.uid},
      'fullName': {'stringValue': model.fullName},
      'email': {'stringValue': model.email},
      'phoneNumber': {'stringValue': model.phoneNumber},
      'role': {'stringValue': model.role},
      'accountRole': {'stringValue': model.accountRole},
      'organization': {'stringValue': model.organization},
      'assignedArea': {'stringValue': model.assignedArea},
      'profileImage': {'stringValue': model.profileImage},
      'isActive': {'booleanValue': model.isActive},
      'fieldPersonnelVerified': {
        'booleanValue': model.fieldPersonnelVerified,
      },
      'personnelVerifiedBy': {
        'stringValue': model.personnelVerifiedBy,
      },
    };
    if (includeCreatedAt) {
      fields['createdAt'] = {
        'timestampValue': DateTime.now().toUtc().toIso8601String(),
      };
    }
    return fields;
  }

  String _messageForHttp(String action, http.Response response) {
    if (kDebugMode) {
      debugPrint(
          'WindowsAuthRest $action failed: ${response.statusCode} ${response.body}');
    }
    return 'Could not $action (${response.statusCode}). Check your connection.';
  }

  String _messageForIdentityError(Map<String, dynamic> error) {
    final message = (error['message'] as String?) ?? 'UNKNOWN';
    switch (message) {
      case 'EMAIL_EXISTS':
        return 'This email is already registered. Try signing in instead.';
      case 'WEAK_PASSWORD':
        return 'Password is too weak. Use at least 8 characters.';
      case 'INVALID_EMAIL':
        return 'That email address doesn\'t look valid.';
      case 'EMAIL_NOT_FOUND':
        return 'No account found for that email.';
      case 'INVALID_PASSWORD':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Incorrect email or password.';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'Too many attempts. Try again later.';
      case 'OPERATION_NOT_ALLOWED':
        return 'Email/password sign-in is disabled in Firebase Console. '
            'Enable it under Authentication → Sign-in method → Email/Password.';
      case 'CONFIGURATION_NOT_FOUND':
        return 'Firebase Authentication is not set up for this project yet. '
            'Open Firebase Console → Authentication → Get started, then enable '
            'Email/Password. Project: ${_options.projectId}. '
            'See FIREBASE_SETUP.md in the repo for steps.';
      case 'API_KEY_INVALID':
        return 'Invalid Firebase API key. Re-run flutterfire configure and rebuild the app.';
      default:
        if (message.contains('CONFIGURATION_NOT_FOUND')) {
          return 'Firebase Authentication is not set up for this project yet. '
              'Open Firebase Console → Authentication → Get started, then enable '
              'Email/Password.';
        }
        return 'Authentication failed: ${message.replaceAll('_', ' ')}.';
    }
  }
}

class WindowsAuthSession {
  const WindowsAuthSession({
    required this.uid,
    required this.email,
    required this.idToken,
  });

  final String uid;
  final String email;
  final String idToken;
}

class WindowsAuthRestException implements Exception {
  const WindowsAuthRestException(this.message);
  final String message;

  @override
  String toString() => message;
}
