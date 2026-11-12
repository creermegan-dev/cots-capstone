import 'package:cots_monitor/features/auth/widgets/auth_responsive_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [const Size(1440, 900), const Size(1200, 800)]) {
    testWidgets('desktop auth card is vertically centered at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(
        home: AuthResponsiveScaffold(
          desktopHeader: AuthCardHeader(
            showLogo: false,
            title: 'Welcome back',
            subtitle: 'Sign in to continue monitoring.',
          ),
          formChild: SizedBox(height: 280),
          footer: Text('Sign Up'),
        ),
      ));
      await tester.pumpAndSettle();

      final card = tester.getRect(find.byType(AuthFormCard));
      expect(card.center.dy, closeTo(size.height / 2, 1));
      expect(card.top, greaterThanOrEqualTo(20));
      expect(card.bottom, lessThanOrEqualTo(size.height - 20));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tall auth form remains scrollable on a short desktop',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var submitted = false;

    await tester.pumpWidget(MaterialApp(
      home: AuthResponsiveScaffold(
        desktopHeader: const AuthCardHeader(
          showLogo: false,
          title: 'Create Account',
          subtitle: 'Join COTS Monitor.',
        ),
        formChild: const SizedBox(height: 780),
        footer: FilledButton(
          onPressed: () => submitted = true,
          child: const Text('Submit form'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(AuthFormCard)).top, closeTo(20, 1));

    final scroll = find.ancestor(
      of: find.byType(AuthFormCard),
      matching: find.byType(SingleChildScrollView),
    );
    await tester.drag(scroll, const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit form'));
    expect(submitted, isTrue);
    expect(tester.takeException(), isNull);
  });
}
