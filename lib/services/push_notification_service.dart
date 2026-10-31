import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/firebase_bootstrap.dart';
import '../core/supabase_config.dart';

/// Registers the signed-in user's device for server-sent Firebase notifications.
///
/// Foreground activity is already shown by the existing Firestore notification
/// stream. FCM supplies the system notification while the app is backgrounded
/// or closed.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  FirebaseMessaging? _messaging;
  StreamSubscription<String>? _tokenSubscription;
  String? _activeUid;
  String? _currentToken;
  bool _initializing = false;

  bool get _supportsPush =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> setActiveUser(String? uid) async {
    if (!_supportsPush || SupabaseConfig.isConfigured || _initializing) return;
    final normalized = uid?.trim();
    if (normalized == _activeUid) return;

    _initializing = true;
    try {
      final previousUid = _activeUid;
      final previousToken = _currentToken;
      _activeUid = normalized;

      if (previousUid != null && previousToken != null) {
        await _removeToken(previousUid, previousToken);
      }
      _currentToken = null;
      await _tokenSubscription?.cancel();
      _tokenSubscription = null;

      if (normalized == null || normalized.isEmpty) return;
      await ensureFirebaseInitialized();
      final messaging = _messaging ??= FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty && _activeUid == normalized) {
        _currentToken = token;
        await _saveToken(normalized, token);
      }
      _tokenSubscription = messaging.onTokenRefresh.listen((token) {
        unawaited(_replaceToken(normalized, token));
      });
    } catch (error, stack) {
      debugPrint('Push notification setup failed: $error\n$stack');
    } finally {
      _initializing = false;
    }
  }

  Future<void> _replaceToken(String uid, String nextToken) async {
    if (_activeUid != uid || nextToken.isEmpty) return;
    final previous = _currentToken;
    if (previous == nextToken) return;
    if (previous != null) await _removeToken(uid, previous);
    if (_activeUid != uid) return;
    _currentToken = nextToken;
    await _saveToken(uid, nextToken);
  }

  Future<void> _saveToken(String uid, String token) {
    return FirebaseFirestore.instance
        .collection('push_tokens')
        .doc(tokenDocumentId(token))
        .set(<String, dynamic>{
      'uid': uid,
      'token': token,
      'platform': defaultTargetPlatform.name,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _removeToken(String uid, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection('push_tokens')
          .doc(tokenDocumentId(token))
          .delete();
    } catch (error) {
      debugPrint('Could not remove push token for $uid: $error');
    }
  }

  @visibleForTesting
  static String tokenDocumentId(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
  }
}
