import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// "Remember me" on the login screen also remembers the email address, so it
/// is filled in next time. Only the email is kept, never the password, and it
/// is stored in the phone's protected storage.
abstract final class RememberedLogin {
  static const _emailKey = 'cots_monitor.remembered_email.v1';
  static const _storage = FlutterSecureStorage();

  /// The saved email, or an empty string when none is saved.
  static Future<String> email() async {
    try {
      return (await _storage.read(key: _emailKey))?.trim() ?? '';
    } on Object {
      return '';
    }
  }

  /// Saves [email] when [remember] is true; forgets it otherwise.
  static Future<void> save({required String email, required bool remember}) async {
    final value = email.trim();
    try {
      if (remember && value.isNotEmpty) {
        await _storage.write(key: _emailKey, value: value);
      } else {
        await _storage.delete(key: _emailKey);
      }
    } on Object {
      // Remembering the email is a convenience; sign-in must not fail on it.
    }
  }
}
