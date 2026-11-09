import 'dart:async';

import 'package:cots_monitor/features/auth/password_recovery_screen.dart';
import 'package:cots_monitor/services/password_recovery_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeRecovery extends PasswordRecoveryService {
  _FakeRecovery()
      : super(
            client: SupabaseClient('http://localhost:54321', 'fixture',
                authOptions: const AuthClientOptions(autoRefreshToken: false)));
  int sends = 0, verifies = 0, saves = 0, closes = 0;
  bool badCode = false, rateLimited = false;
  Completer<void>? pendingSend;
  @override
  Future<void> sendCode(String email) async {
    sends++;
    if (rateLimited) {
      throw const AuthException('Rate limited',
          code: 'over_email_send_rate_limit');
    }
    await pendingSend?.future;
  }

  @override
  Future<void> verifyCode(String email, String code) async {
    verifies++;
    if (badCode) throw const AuthException('Expired', code: 'otp_expired');
  }

  @override
  Future<void> setNewPassword(String password) async {
    saves++;
  }

  @override
  Future<void> dispose() async {
    closes++;
    await super.dispose();
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final layout in [(360.0, 1.0), (360.0, 2.0), (1200.0, 1.0)]) {
    testWidgets('email/code/password flow validates and fits $layout',
        (tester) async {
      tester.view.physicalSize = Size(layout.$1, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _FakeRecovery();
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(layout.$2)),
            child: child!),
        home: PasswordRecoveryScreen(service: service),
      ));
      await tapText(tester, 'Send recovery code');
      expect(service.sends, 0);
      await tester.enterText(
          find.byType(TextFormField), 'diver@example.invalid');
      await tapText(tester, 'Send recovery code');
      expect(service.sends, 1);
      expect(find.text('Check your email'), findsOneWidget);
      final resend = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Send new code in 60s'));
      expect(resend.onPressed, isNull);
      await tester.enterText(find.byType(TextFormField), '123456');
      service.badCode = true;
      await tapText(tester, 'Verify code');
      expect(find.textContaining('incorrect or has expired'), findsOneWidget);
      expect(service.saves, 0);
      service.badCode = false;
      await tapText(tester, 'Verify code');
      expect(find.text('Choose a new password'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), 'Short');
      await tester.enterText(find.byType(TextFormField).at(1), 'Different');
      await tapText(tester, 'Save new password');
      expect(service.saves, 0);
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await tester.enterText(
          find.byType(TextFormField).at(0), 'LongFixturePassword!');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'LongFixturePassword!');
      await tapText(tester, 'Save new password');
      expect(service.saves, 1);
      expect(find.text('Password changed'), findsOneWidget);
      expect(find.text('Back to login'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(service.closes, 1);
    });
  }
  testWidgets(
      'busy state prevents duplicate requests and rate-limit errors keep email',
      (tester) async {
    final service = _FakeRecovery()..pendingSend = Completer<void>();
    await tester.pumpWidget(MaterialApp(
        home: PasswordRecoveryScreen(
            initialEmail: 'diver@example.invalid', service: service)));
    await tester.tap(find.text('Send recovery code'));
    await tester.tap(find.text('Send recovery code'));
    await tester.pump();
    expect(service.sends, 1);
    service.pendingSend!.complete();
    await tester.pumpAndSettle();
    await tapText(tester, 'Start again');
    service.rateLimited = true;
    service.pendingSend = null;
    await tapText(tester, 'Send recovery code');
    expect(find.textContaining('Too many attempts'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'diver@example.invalid');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('cancel returns to login and disposes recovery without saving',
      (tester) async {
    final service = _FakeRecovery();
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) =>
                              PasswordRecoveryScreen(service: service))),
                  child: const Text('Login home'),
                )))));
    await tapText(tester, 'Login home');
    await tapText(tester, 'Cancel');
    expect(find.text('Login home'), findsOneWidget);
    expect(service.saves, 0);
    expect(service.closes, 1);
  });
}
