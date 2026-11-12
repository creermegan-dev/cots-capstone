import 'package:cots_monitor/core/cots_theme.dart';
import 'package:cots_monitor/features/auth/widgets/cots_auth_password_field.dart';
import 'package:cots_monitor/features/auth/widgets/cots_auth_text_field.dart';
import 'package:cots_monitor/features/auth/widgets/cots_gradient_primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('validation stays within the field at enlarged text size',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final form = GlobalKey<FormState>();
    const message = 'Enter a valid email address before continuing.';

    await tester.pumpWidget(MaterialApp(
      theme: cotsTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: form,
            child: CotsAuthTextField(
              controller: controller,
              label: 'Email Address',
              hint: 'name@example.com',
              prefixIcon: Icons.mail_outline,
              validator: (_) => message,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final originalHeight =
        tester.getSize(find.byType(CotsAuthTextField)).height;
    expect(form.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    final field = tester.getRect(find.byType(CotsAuthTextField));
    expect(field.height, greaterThan(originalHeight));
    expect(tester.getRect(find.text(message)).bottom,
        lessThanOrEqualTo(field.bottom + 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('password visibility remains available with the new field style',
      (tester) async {
    final controller = TextEditingController(text: 'test password');
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: cotsTheme(),
      home: Scaffold(
        body: CotsAuthPasswordField(
          controller: controller,
          label: 'Password',
          hint: 'Enter your password',
        ),
      ),
    ));
    expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText, isFalse);
    expect(controller.text, 'test password');
  });

  testWidgets('a loading primary action cannot submit again', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(MaterialApp(
      theme: cotsTheme(),
      home: Scaffold(
        body: CotsGradientPrimaryButton(
          label: 'Continue',
          isLoading: true,
          onPressed: () => pressed++,
        ),
      ),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(CotsGradientPrimaryButton));
    await tester.pump();
    expect(pressed, 0);
    expect(tester.takeException(), isNull);
  });
}
