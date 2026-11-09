import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import 'supabase_auth_service.dart';

/// Owns a temporary, non-persisted client, separate from the app's sign-in.
/// Recovery never opens a dashboard or marks a device as trusted.
class PasswordRecoveryService {
  PasswordRecoveryService({SupabaseClient? client})
      : _client = client ??
            SupabaseClient(
              SupabaseConfig.url,
              SupabaseConfig.publishableKey,
              authOptions: const AuthClientOptions(
                autoRefreshToken: false,
                authFlowType: AuthFlowType.implicit,
              ),
            );

  static const minimumPasswordLength = 12;
  final SupabaseClient _client;
  String? _verifiedEmail;
  bool _closed = false;

  bool get canResetPassword {
    final session = _client.auth.currentSession;
    final expiry = session?.expiresAt;
    return !_closed &&
        _verifiedEmail != null &&
        session != null &&
        expiry != null &&
        DateTime.now().millisecondsSinceEpoch ~/ 1000 < expiry;
  }

  Future<void> sendCode(String email) async {
    _ensureOpen();
    _verifiedEmail = null;
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (error) {
      // Do not reveal whether an address has an account. /recover cannot
      // create an account, unlike a passwordless signup request.
      if (error.code != 'user_not_found') rethrow;
    }
  }

  Future<void> verifyCode(String email, String code) async {
    _ensureOpen();
    _verifiedEmail = null;
    if (!SupabaseAuthService.isValidCode(code)) {
      throw StateError('Enter the recovery code from your email.');
    }
    final response = await _client.auth.verifyOTP(
      email: email.trim(),
      token: SupabaseAuthService.normalizeCode(code),
      type: OtpType.recovery,
    );
    _ensureOpen();
    if (response.session == null ||
        response.user?.email?.toLowerCase() != email.trim().toLowerCase()) {
      throw StateError('Recovery could not be verified. Request a new code.');
    }
    _verifiedEmail = email.trim().toLowerCase();
  }

  Future<void> setNewPassword(String password) async {
    if (!canResetPassword) {
      throw StateError('Recovery has expired. Request a new code.');
    }
    if (password.length < minimumPasswordLength) {
      throw StateError('Use at least $minimumPasswordLength characters.');
    }
    await _client.auth.updateUser(UserAttributes(password: password));
    _verifiedEmail = null;
    // Cleanup failure must not misreport a successful password change.
    await _clearSession();
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Recovery is closed. Please start again.');
  }

  Future<void> _clearSession() async {
    if (_client.auth.currentSession == null) return;
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } on Object {
      // This isolated client is disposed without persisting its session.
    }
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    _verifiedEmail = null;
    await _clearSession();
    await _client.dispose();
  }
}
