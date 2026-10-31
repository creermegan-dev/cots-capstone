import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stores the serialized Supabase session in platform-protected storage.
///
/// Android uses the system keystore and Windows uses Credential Manager-backed
/// encryption through `flutter_secure_storage`.
///
/// "Remember me": when the person signs in with it unticked, the saved session
/// is discarded the next time the app starts after being fully closed, so they
/// must sign in again. The trusted-device secret is stored separately and is
/// never affected, so signing in again on the same device needs no email code.
final class SecureSupabaseLocalStorage extends LocalStorage {
  const SecureSupabaseLocalStorage();

  static const _sessionKey = 'cots_monitor.supabase.session.v1';
  static const _rememberKey = 'cots_monitor.remember_session.v1';
  static const _sessionOnly = 'session_only';
  static const _storage = FlutterSecureStorage();

  /// Saves the "Remember me" choice. Call it before signing in.
  static Future<void> setRememberSession(bool remember) => remember
      ? _storage.delete(key: _rememberKey)
      : _storage.write(key: _rememberKey, value: _sessionOnly);

  /// The last "Remember me" choice (true when never set).
  static Future<bool> rememberSession() async {
    try {
      return await _storage.read(key: _rememberKey) != _sessionOnly;
    } on Object {
      return true;
    }
  }

  /// Runs once per app start, before Supabase restores a saved session.
  @override
  Future<void> initialize() async {
    if (!await rememberSession()) {
      await _storage.delete(key: _sessionKey);
    }
  }

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _sessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _sessionKey);
}
