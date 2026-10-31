import 'dart:async';
import 'dart:math';

import 'package:cots_monitor/core/device_identity.dart';
import 'package:cots_monitor/models/pending_email_verification.dart';
import 'package:cots_monitor/models/user_model.dart';
import 'package:cots_monitor/providers/auth_provider.dart';
import 'package:cots_monitor/services/supabase_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FixedDeviceSecret implements DeviceSecretSource {
  @override
  Future<String> readOrCreate() async => 'A' * 43;
}

/// In-memory stand-in for Supabase Auth and the register_device RPC.
class _FakeAuthService extends SupabaseAuthService {
  _FakeAuthService({this.emailConfirmed = true})
      : super(
          client: SupabaseClient(
            'http://localhost:54321',
            'test-publishable-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  bool emailConfirmed;
  final List<String> calls = <String>[];
  final List<String> trustResults = <String>[];
  final StreamController<AuthState> _events =
      StreamController<AuthState>.broadcast();
  Session? _session;

  Session _newSession() => Session(
        accessToken: 'header.payload.signature',
        tokenType: 'bearer',
        user: User(
          id: '00000000-0000-4000-8000-000000000001',
          appMetadata: const <String, dynamic>{},
          userMetadata: const <String, dynamic>{},
          aud: 'authenticated',
          createdAt: DateTime.utc(2026).toIso8601String(),
          email: 'diver@example.invalid',
        ),
      );

  void _signedIn() {
    _session = _newSession();
    _events.add(AuthState(AuthChangeEvent.signedIn, _session));
  }

  @override
  Stream<AuthState> authStateChanges() => _events.stream;

  @override
  Session? get currentSession => _session;

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    calls.add('signIn');
    if (!emailConfirmed) {
      throw const AuthException(
        'Email not confirmed',
        statusCode: '400',
        code: 'email_not_confirmed',
      );
    }
    _signedIn();
    return AuthResponse(session: _session);
  }

  @override
  Future<String> registerDevice(String deviceSecret) async {
    calls.add('registerDevice');
    expect(DeviceIdentity.isValidSecret(deviceSecret), isTrue);
    return trustResults.isEmpty
        ? SupabaseAuthService.deviceTrusted
        : trustResults.removeAt(0);
  }

  @override
  Future<void> sendLoginCode(String email) async => calls.add('sendLoginCode');

  @override
  Future<void> resendSignupConfirmation(String email) async =>
      calls.add('resendSignup');

  @override
  Future<AuthResponse> verifyLoginCode({
    required String email,
    required String code,
  }) async {
    calls.add('verifyLoginCode:$code');
    _signedIn();
    return AuthResponse(session: _session);
  }

  @override
  Future<AuthResponse> verifySignupCode({
    required String email,
    required String code,
  }) async {
    calls.add('verifySignupCode:$code');
    emailConfirmed = true;
    _signedIn();
    return AuthResponse(session: _session);
  }

  @override
  Future<void> completeSignupProfile() async => calls.add('completeProfile');

  @override
  Future<UserModel> loadProfile(User user) async {
    calls.add('loadProfile');
    return UserModel(
      uid: user.id,
      fullName: 'Test Diver',
      email: user.email ?? '',
      phoneNumber: '',
      role: 'Volunteer Diver',
      organization: '',
      assignedArea: '',
      createdAt: null,
      profileImage: '',
      isActive: true,
    );
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _session = null;
    _events.add(const AuthState(AuthChangeEvent.signedOut, null));
  }
}

AuthProvider _provider(_FakeAuthService service) => AuthProvider(
      supabaseAuthService: service,
      deviceSecretSource: _FixedDeviceSecret(),
      useSupabaseForTesting: true,
    );

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('trusted device signs in with password only', () async {
    final service = _FakeAuthService();
    final auth = _provider(service);

    await auth.signIn(email: 'diver@example.invalid', password: 'pw');
    await _settle();

    expect(auth.pendingEmailVerification, isNull);
    expect(auth.userModel?.fullName, 'Test Diver');
    expect(service.calls, isNot(contains('sendLoginCode')));
    expect(service.calls.indexOf('registerDevice'),
        lessThan(service.calls.indexOf('loadProfile')));
  });

  test('new device needs the emailed code before any data loads', () async {
    final service = _FakeAuthService()
      ..trustResults.addAll(<String>[
        SupabaseAuthService.deviceVerificationRequired,
        SupabaseAuthService.deviceTrusted,
      ]);
    final auth = _provider(service);

    await auth.signIn(email: 'diver@example.invalid', password: 'pw');
    await _settle();

    expect(auth.pendingEmailVerification?.reason,
        EmailVerificationReason.newDevice);
    expect(auth.userModel, isNull);
    expect(service.calls, contains('sendLoginCode'));
    expect(service.calls, isNot(contains('loadProfile')));

    await auth.verifyEmailCode('123 456');
    await _settle();

    expect(service.calls, contains('verifyLoginCode:123 456'));
    expect(auth.pendingEmailVerification, isNull);
    expect(auth.userModel, isNotNull);
  });

  test('resend respects the 60-second cooldown', () async {
    final service = _FakeAuthService()
      ..trustResults.add(SupabaseAuthService.deviceVerificationRequired);
    final auth = _provider(service);

    await auth.signIn(email: 'diver@example.invalid', password: 'pw');
    await auth.resendEmailCode();

    expect(service.calls.where((c) => c == 'sendLoginCode'), hasLength(1));
  });

  test('first sign-in verifies the signup code, then the password', () async {
    final service = _FakeAuthService(emailConfirmed: false)
      ..trustResults.addAll(<String>[
        SupabaseAuthService.deviceVerificationRequired,
        SupabaseAuthService.deviceTrusted,
      ]);
    final auth = _provider(service);

    await auth.signIn(email: 'diver@example.invalid', password: 'pw');
    await _settle();

    expect(auth.pendingEmailVerification?.reason,
        EmailVerificationReason.firstLogin);
    expect(auth.isAuthenticated, isFalse);
    // The signup email already contains the code; nothing is re-sent.
    expect(service.calls, isNot(contains('resendSignup')));

    await auth.verifyEmailCode('654321');
    await _settle();

    expect(service.calls, containsAllInOrder(<String>[
      'verifySignupCode:654321',
      'registerDevice',
      'signIn',
      'registerDevice',
      'completeProfile',
      'loadProfile',
    ]));
    expect(auth.pendingEmailVerification, isNull);
    expect(auth.userModel, isNotNull);
  });

  test('malformed codes are rejected without contacting Supabase', () async {
    final service = _FakeAuthService()
      ..trustResults.add(SupabaseAuthService.deviceVerificationRequired);
    final auth = _provider(service);
    await auth.signIn(email: 'diver@example.invalid', password: 'pw');
    service.calls.clear();

    await expectLater(auth.verifyEmailCode('12ab'), throwsFormatException);
    expect(service.calls, isEmpty);
    expect(auth.pendingEmailVerification, isNotNull);
  });

  test('a code that does not complete verification keeps data locked',
      () async {
    final service = _FakeAuthService()
      ..trustResults.addAll(<String>[
        SupabaseAuthService.deviceVerificationRequired,
        SupabaseAuthService.deviceVerificationRequired,
      ]);
    final auth = _provider(service);
    await auth.signIn(email: 'diver@example.invalid', password: 'pw');

    await expectLater(auth.verifyEmailCode('123456'), throwsStateError);
    expect(auth.userModel, isNull);
    expect(auth.lastError, contains('could not be verified'));
  });

  test('cancel signs out and clears the pending step', () async {
    final service = _FakeAuthService()
      ..trustResults.add(SupabaseAuthService.deviceVerificationRequired);
    final auth = _provider(service);
    await auth.signIn(email: 'diver@example.invalid', password: 'pw');

    await auth.cancelEmailVerification();
    await _settle();

    expect(service.calls, contains('signOut'));
    expect(auth.pendingEmailVerification, isNull);
    expect(auth.isAuthenticated, isFalse);
  });

  group('helpers', () {
    test('device secrets are 43-character base64url values', () {
      final secret = DeviceIdentity.generateSecret(Random(7));
      expect(secret, hasLength(43));
      expect(DeviceIdentity.isValidSecret(secret), isTrue);
      expect(DeviceIdentity.isValidSecret('short'), isFalse);
    });

    test('codes are normalized and validated', () {
      expect(SupabaseAuthService.normalizeCode(' 123-456 '), '123456');
      expect(SupabaseAuthService.isValidCode('123 456'), isTrue);
      expect(SupabaseAuthService.isValidCode('12345'), isFalse);
      expect(SupabaseAuthService.isValidCode('12345a'), isFalse);
    });

    test('email-not-confirmed errors are recognized', () {
      expect(
        SupabaseAuthService.isEmailNotConfirmed(
          const AuthException('x', code: 'email_not_confirmed'),
        ),
        isTrue,
      );
      expect(
        SupabaseAuthService.isEmailNotConfirmed(
          const AuthException('Invalid login credentials',
              code: 'invalid_credentials'),
        ),
        isFalse,
      );
    });

    test('resend cooldown counts down from 60 seconds', () {
      final sent = DateTime(2026, 10, 30, 12);
      final pending = const PendingEmailVerification(
        email: 'd@example.invalid',
        reason: EmailVerificationReason.newDevice,
      ).withCodeSentAt(sent);
      expect(pending.secondsUntilResend(sent), 60);
      expect(
          pending.secondsUntilResend(sent.add(const Duration(seconds: 59))),
          1);
      expect(
          pending.secondsUntilResend(sent.add(const Duration(seconds: 60))),
          0);
      expect(
          pending.secondsUntilResend(sent.add(const Duration(seconds: 61))),
          0);
    });
  });
}
