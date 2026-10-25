import 'dart:async';

import 'package:cots_monitor/features/admin/screens/admin_settings_screen.dart';
import 'package:cots_monitor/models/admin_preferences.dart';
import 'package:cots_monitor/models/user_model.dart';
import 'package:cots_monitor/providers/auth_provider.dart';
import 'package:cots_monitor/services/admin_preferences_repository.dart';
import 'package:cots_monitor/widgets/cots_loading_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test('admin preference parsing retains safe defaults', () {
    final preferences = AdminPreferences.fromMap('admin-1', {
      'email_notifications': false,
      'weekly_reports': true,
      'login_alerts': 'invalid',
    });

    expect(preferences.uid, 'admin-1');
    expect(preferences.emailNotifications, isFalse);
    expect(preferences.weeklyReports, isTrue);
    expect(preferences.loginAlerts, isTrue);
    expect(preferences.highRiskAlerts, isTrue);
  });

  test('Firestore REST values decode into preferences', () {
    final preferences = AdminPreferences.fromRestDocument('admin-1', {
      'fields': {
        'email_notifications': {'booleanValue': false},
        'two_factor_auth': {'booleanValue': true},
      },
    });

    expect(preferences.emailNotifications, isFalse);
    expect(preferences.twoFactorAuth, isTrue);
    expect(preferences.systemUpdates, isTrue);
  });

  testWidgets('admin settings load and save persisted preferences',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pending = Completer<AdminPreferences>();
    final store = _FakePreferencesStore(pending.future);
    final auth = _AdminAuth();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: Scaffold(
            body: AdminSettingsScreen(preferencesStore: store),
          ),
        ),
      ),
    );
    expect(find.byType(CotsLoadingSkeleton), findsOneWidget);

    pending.complete(const AdminPreferences(
      uid: 'admin-1',
      emailNotifications: false,
      highRiskAlerts: true,
      systemUpdates: false,
      weeklyReports: true,
      twoFactorAuth: true,
      loginAlerts: false,
      sessionTimeout: true,
    ));
    await tester.pumpAndSettle();

    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches.map((item) => item.value),
        [false, true, false, true, true, false, true]);

    final weeklyReportsSwitch = find.byType(Switch).at(3);
    await tester.ensureVisible(weeklyReportsSwitch);
    await tester.pumpAndSettle();
    await tester.tap(weeklyReportsSwitch);
    final saveButton = find.text('Save Preferences').first;
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(store.saved, isNotNull);
    expect(store.saved!.uid, 'admin-1');
    expect(store.saved!.weeklyReports, isFalse);
    expect(find.text('Preferences saved.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakePreferencesStore implements AdminPreferencesStore {
  _FakePreferencesStore(this.result);

  final Future<AdminPreferences> result;
  AdminPreferences? saved;

  @override
  Future<AdminPreferences> load(String uid) => result;

  @override
  Future<void> save(AdminPreferences preferences) async {
    saved = preferences;
  }
}

class _AdminAuth extends ChangeNotifier implements AuthProvider {
  @override
  UserModel get userModel => const UserModel(
        uid: 'admin-1',
        fullName: 'Admin User',
        email: 'admin@example.com',
        phoneNumber: '',
        role: 'Administrator',
        organization: 'COTS Monitor',
        assignedArea: '',
        createdAt: null,
        profileImage: '',
        isActive: true,
        accountRole: UserModel.adminAccountRole,
      );

  @override
  String? get lastError => null;

  @override
  Future<void> refreshProfile() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
