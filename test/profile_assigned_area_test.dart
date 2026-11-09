import 'package:cots_monitor/core/supabase_config.dart';
import 'package:cots_monitor/features/user/profile_page.dart';
import 'package:cots_monitor/models/user_model.dart';
import 'package:cots_monitor/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  for (final width in [360.0, 1200.0]) {
    testWidgets('profile area field and save summary respect backend ($width)',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = _ProfileAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: PersonalInformationPage()),
      ));
      await tester.pumpAndSettle();

      final areaMatcher =
          SupabaseConfig.isConfigured ? findsNothing : findsOneWidget;
      expect(find.text('Assigned Area'), areaMatcher);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(auth.saved, isTrue);
      // The hidden legacy value is preserved, not overwritten by this UI fix.
      expect(auth.savedArea, 'Legacy reef');
      expect(find.text('Changes Saved Successfully!'), findsOneWidget);
      expect(find.text('Assigned Area:'), areaMatcher);
      expect(find.text('Organization:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _ProfileAuth extends ChangeNotifier implements AuthProvider {
  bool saved = false;
  String? savedArea;

  @override
  UserModel get userModel => const UserModel(
        uid: 'diver-1',
        fullName: 'Test Diver',
        email: 'diver@example.invalid',
        phoneNumber: '09123456789',
        role: 'Diver',
        organization: 'BFAR',
        assignedArea: 'Legacy reef',
        createdAt: null,
        profileImage: '',
        isActive: true,
      );

  @override
  void clearLastError() {}

  @override
  String? get lastError => null;

  @override
  Future<void> updateProfile({
    required String fullName,
    required String phoneNumber,
    required String role,
    required String organization,
    required String assignedArea,
  }) async {
    saved = true;
    savedArea = assignedArea;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
