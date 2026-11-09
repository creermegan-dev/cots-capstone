import 'package:cots_monitor/features/admin/screens/admin_users_screen.dart';
import 'package:cots_monitor/features/expert/screens/expert_dashboard_screen.dart';
import 'package:cots_monitor/features/expert/screens/expert_notifications_screen.dart';
import 'package:cots_monitor/features/expert/screens/expert_users_screen.dart';
import 'package:cots_monitor/features/expert/models/expert_action_item.dart';
import 'package:cots_monitor/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [390.0, 1400.0]) {
    testWidgets('expert dashboard routes existing work at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final actions = ExpertActionsController(
        records: () => Stream.value([]),
        reassignments: () => Stream.value([]),
        supabase: false,
        refreshEvery: null,
      )..start();
      addTearDown(actions.dispose);
      ExpertActionPlace? opened;
      var mapOpened = false;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ExpertDashboardScreen(
        actions: actions,
        onOpen: (place) => opened = place,
        onOpenMap: () => mapOpened = true,
      ))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Site Coverage'));
      expect(opened, ExpertActionPlace.reassignments);
      await tester.ensureVisible(find.text('Open Map Monitoring'));
      await tester.tap(find.text('Open Map Monitoring'));
      expect(mapOpened, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'admin directory displays real verification status without decisions',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final users = [
      UserModel.fromSupabaseProfile({
        'id': 'one',
        'full_name': 'Diver One',
        'active': true,
        'field_verified': true
      }, email: 'one@example.invalid'),
      UserModel.fromSupabaseProfile({
        'id': 'two',
        'full_name': 'Diver Two',
        'active': true,
        'field_verified': false
      }, email: 'two@example.invalid'),
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdminUsersScreen(usersStream: Stream.value(users)))));
    await tester.pumpAndSettle();
    expect(find.text('Expert verification'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Awaiting verification'), findsOneWidget);
    expect(find.text('Verify'), findsNothing);
    expect(find.text('Revoke'), findsNothing);
    expect(find.text('Disable'), findsNothing);
    expect(find.text('Supervised account recovery'), findsNothing);
    expect(
        find.byTooltip('Approve supervised password recovery'), findsNothing);
    expect(find.byIcon(Icons.key_rounded), findsNothing);
    await tester.ensureVisible(find.byTooltip('View').first);
    await tester.tap(find.byTooltip('View').first);
    await tester.pumpAndSettle();
    expect(find.text('Approve supervised recovery?'), findsNothing);
    expect(find.text('Verification reference'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expert personnel page explains verification scope',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ExpertUsersScreen(loadUsers: () async => []))));
    await tester.pumpAndSettle();
    expect(find.text('Personnel Verification'), findsOneWidget);
    expect(
        find.textContaining(
            'account activation and existing records are unchanged'),
        findsOneWidget);
    expect(find.text('Verify'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
