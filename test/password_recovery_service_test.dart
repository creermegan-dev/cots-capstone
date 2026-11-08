import 'dart:convert';

import 'package:cots_monitor/services/password_recovery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> testUser() => {
      'id': '00000000-0000-4000-8000-000000000001',
      'aud': 'authenticated',
      'email': 'diver@example.invalid',
      'created_at': '2026-11-01T00:00:00Z',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
    };

Map<String, dynamic> testSession({bool expired = false}) {
  final expiry =
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + (expired ? -60 : 3600);
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return {
    'access_token': '${encode({'alg': 'HS256'})}.${encode({
          'sub': testUser()['id'],
          'exp': expiry,
          'amr': [
            {'method': 'recovery'}
          ]
        })}.test',
    'refresh_token': 'fixture-refresh',
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': expiry,
    'user': testUser()
  };
}

void main() {
  late List<http.Request> requests;
  late SupabaseClient client;
  late PasswordRecoveryService service;
  var badCode = false;
  var expired = false;
  var unknown = false;
  var emptySession = false;
  var rejectPassword = false;
  setUp(() {
    requests = [];
    badCode = false;
    expired = false;
    unknown = false;
    emptySession = false;
    rejectPassword = false;
    client = SupabaseClient(
      'https://recovery.example.invalid',
      'fixture-public-key',
      authOptions: const AuthClientOptions(
          autoRefreshToken: false, authFlowType: AuthFlowType.implicit),
      httpClient: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        Object body = <String, dynamic>{};
        int status = 200;
        if (path.endsWith('/recover') && unknown) {
          body = {'code': 'user_not_found', 'msg': 'User not found'};
          status = 400;
        } else if (path.endsWith('/verify')) {
          if (badCode) {
            body = {'code': 'otp_expired', 'msg': 'Invalid code'};
            status = 403;
          } else {
            body = emptySession
                ? <String, dynamic>{'user': testUser()}
                : testSession(expired: expired);
          }
        } else if (path.endsWith('/user') && request.method == 'PUT') {
          if (rejectPassword) {
            body = {'code': 'weak_password', 'msg': 'Weak password'};
            status = 422;
          } else {
            body = testUser();
          }
        } else if (!path.endsWith('/recover') && !path.endsWith('/logout')) {
          throw StateError('Unexpected Auth request: $path');
        }
        return http.Response(jsonEncode(body), status, headers: {
          'content-type': 'application/json',
          'x-supabase-api-version': '2024-01-01',
        });
      }),
    );
    service = PasswordRecoveryService(client: client);
  });
  tearDown(() => service.dispose());

  test('request uses recovery endpoint, trims email, and never signs up',
      () async {
    await service.sendCode(' diver@example.invalid ');
    expect(requests.single.url.path, '/auth/v1/recover');
    expect(jsonDecode(requests.single.body)['email'], 'diver@example.invalid');
    expect(service.canResetPassword, isFalse);
    expect(client.auth.currentSession, isNull);
  });
  test('unknown email has the same send-code result', () async {
    unknown = true;
    await service.sendCode('unknown@example.invalid');
    expect(service.canResetPassword, isFalse);
    expect(requests.where((r) => r.url.path.endsWith('/signup')), isEmpty);
  });
  test('cannot change a password without verified recovery proof', () async {
    await expectLater(
        service.setNewPassword('LongFixturePassword!'), throwsStateError);
    expect(requests, isEmpty);
  });
  test(
      'code verification uses recovery, updates only password, and clears session',
      () async {
    final other = SupabaseClient('https://other.example.invalid', 'fixture',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(other.dispose);
    await service.verifyCode('diver@example.invalid', '123 456');
    final verify = jsonDecode(requests.single.body);
    expect(verify['type'], 'recovery');
    expect(verify['token'], '123456');
    expect(service.canResetPassword, isTrue);
    expect(other.auth.currentSession, isNull);
    await service.setNewPassword('LongFixturePassword!');
    final update = requests.singleWhere((r) => r.method == 'PUT');
    expect(jsonDecode(update.body), {'password': 'LongFixturePassword!'});
    expect(requests.where((r) => r.url.path.contains('/rpc/')), isEmpty);
    expect(service.canResetPassword, isFalse);
    expect(client.auth.currentSession, isNull);
    expect(other.auth.currentSession, isNull);
  });
  test('incorrect code cannot unlock password changes', () async {
    badCode = true;
    await expectLater(service.verifyCode('diver@example.invalid', '123456'),
        throwsA(isA<AuthException>()));
    await expectLater(
        service.setNewPassword('LongFixturePassword!'), throwsStateError);
    expect(requests.where((r) => r.method == 'PUT'), isEmpty);
  });
  test('expired or incomplete sessions cannot unlock password changes',
      () async {
    expired = true;
    await service.verifyCode('diver@example.invalid', '123456');
    expect(service.canResetPassword, isFalse);
    await expectLater(
        service.setNewPassword('LongFixturePassword!'), throwsStateError);
    expired = false;
    emptySession = true;
    await expectLater(service.verifyCode('diver@example.invalid', '123456'),
        throwsStateError);
    expect(requests.where((r) => r.method == 'PUT'), isEmpty);
  });
  test('resending or changing email invalidates previous proof', () async {
    await service.verifyCode('diver@example.invalid', '123456');
    await service.sendCode('different@example.invalid');
    await expectLater(
        service.setNewPassword('LongFixturePassword!'), throwsStateError);
  });
  test('response for another account is rejected', () async {
    await expectLater(service.verifyCode('different@example.invalid', '123456'),
        throwsStateError);
    expect(service.canResetPassword, isFalse);
  });
  test('weak password errors remain retryable without reporting success',
      () async {
    await service.verifyCode('diver@example.invalid', '123456');
    await expectLater(service.setNewPassword('short'), throwsStateError);
    rejectPassword = true;
    await expectLater(service.setNewPassword('LongFixturePassword!'),
        throwsA(isA<AuthException>()));
    expect(service.canResetPassword, isTrue);
    rejectPassword = false;
    await service.setNewPassword('LongFixturePassword!');
    expect(service.canResetPassword, isFalse);
  });
  test('cancellation closes the temporary session and rejects reuse', () async {
    await service.verifyCode('diver@example.invalid', '123456');
    await service.dispose();
    expect(client.auth.currentSession, isNull);
    await expectLater(
        service.sendCode('diver@example.invalid'), throwsStateError);
    await expectLater(
        service.setNewPassword('LongFixturePassword!'), throwsStateError);
  });
}
