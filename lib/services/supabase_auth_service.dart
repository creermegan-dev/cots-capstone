import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_auth_callback.dart';
import '../models/user_model.dart';

class SupabaseAuthService {
  SupabaseAuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<AuthState> authStateChanges() => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  Future<AuthResponse> signUp({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String positionRole,
    required String organization,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: SupabaseAuthCallback.redirectUrl,
      data: signupMetadata(
        fullName: fullName,
        phoneNumber: phoneNumber,
        positionRole: positionRole,
        organization: organization,
      ),
    );
    if (response.session != null) {
      await updateProfile(
        fullName: fullName,
        phoneNumber: phoneNumber,
        positionRole: positionRole,
        organization: organization,
      );
    }
    return response;
  }

  Future<void> resendSignupConfirmation(String email) {
    return _client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: SupabaseAuthCallback.redirectUrl,
    );
  }

  /// Result of [registerDevice].
  static const String deviceTrusted = 'trusted';
  static const String deviceVerificationRequired = 'verification_required';

  /// Asks the server whether this session runs on a trusted device. The
  /// server records password and email-code proofs from the signed session
  /// token, and trusts the device once both are fresh on the same device.
  Future<String> registerDevice(String deviceSecret) async {
    final result = await _client.rpc<dynamic>(
      'register_device',
      params: <String, dynamic>{'device_secret': deviceSecret},
    );
    final value = result?.toString() ?? '';
    if (value != deviceTrusted && value != deviceVerificationRequired) {
      throw StateError('Unexpected device verification response.');
    }
    return value;
  }

  /// Emails a one-time login code to an existing, confirmed account.
  /// Never creates an account.
  Future<void> sendLoginCode(String email) {
    return _client.auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: false,
    );
  }

  /// Verifies a code from the "Magic Link" (login code) email.
  Future<AuthResponse> verifyLoginCode({
    required String email,
    required String code,
  }) {
    return _client.auth.verifyOTP(
      type: OtpType.email,
      email: email.trim(),
      token: normalizeCode(code),
    );
  }

  /// Verifies the code from the "Confirm signup" email. Newer Supabase Auth
  /// versions accept the `email` type for signup codes; older ones need
  /// `signup`, so a rejected `email` attempt is retried once as `signup`.
  Future<AuthResponse> verifySignupCode({
    required String email,
    required String code,
  }) async {
    final token = normalizeCode(code);
    try {
      return await _client.auth.verifyOTP(
        type: OtpType.email,
        email: email.trim(),
        token: token,
      );
    } on AuthException catch (error) {
      final retryable = error.code == 'otp_expired' ||
          error.code == 'invalid_credentials' ||
          error.code == 'validation_failed' ||
          error.statusCode == '403';
      if (!retryable) rethrow;
      return _client.auth.verifyOTP(
        type: OtpType.signup,
        email: email.trim(),
        token: token,
      );
    }
  }

  static bool isEmailNotConfirmed(AuthException error) =>
      error.code == 'email_not_confirmed' ||
      error.message.toLowerCase().contains('email not confirmed');

  /// Sign-in methods recorded in the session token (for support messages).
  static List<String> sessionMethods(Session? session) {
    final token = session?.accessToken;
    if (token == null) return const <String>[];
    final parts = token.split('.');
    if (parts.length != 3) return const <String>[];
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final amr = payload is Map ? payload['amr'] : null;
      if (amr is! List) return const <String>[];
      return [
        for (final entry in amr)
          if (entry is Map && entry['method'] is String)
            entry['method'] as String,
      ];
    } on Object {
      return const <String>[];
    }
  }

  static String normalizeCode(String code) =>
      code.replaceAll(RegExp(r'[\s-]'), '');

  static bool isValidCode(String code) =>
      RegExp(r'^\d{6,10}$').hasMatch(normalizeCode(code));

  static Map<String, dynamic> signupMetadata({
    required String fullName,
    required String phoneNumber,
    required String positionRole,
    required String organization,
  }) =>
      <String, dynamic>{
        'full_name': fullName.trim(),
        'phone': phoneNumber.trim(),
        'job_title': positionRole.trim(),
        'organization': organization.trim(),
      };

  /// Safely fills any blank editable profile fields from immutable signup
  /// metadata. The RPC cannot modify roles, activation, or field approval.
  Future<void> completeSignupProfile() {
    return _client.rpc<void>('complete_signup_profile');
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _client.auth.signOut(scope: SignOutScope.local);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.auth.updateUser(
      UserAttributes(
        password: newPassword,
        currentPassword: currentPassword,
      ),
    );
  }

  Future<UserModel> loadProfile(User user) async {
    final profile =
        await _client.from('profiles').select().eq('id', user.id).single();
    final slot = await _client
        .from('privileged_role_slots')
        .select('role')
        .eq('user_id', user.id)
        .maybeSingle();
    return UserModel.fromSupabaseProfile(
      Map<String, dynamic>.from(profile),
      email: user.email ?? '',
      privilegedRole: slot?['role'] as String?,
    );
  }

  Future<void> updateProfile({
    required String fullName,
    required String phoneNumber,
    required String positionRole,
    required String organization,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('No signed-in user.');
    await _client.from('profiles').update(<String, dynamic>{
      'full_name': fullName.trim(),
      'phone': phoneNumber.trim(),
      'job_title': positionRole.trim(),
      'organization': organization.trim(),
    }).eq('id', user.id);
  }
}
