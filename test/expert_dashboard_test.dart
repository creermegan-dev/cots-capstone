import 'package:cots_monitor/features/expert/screens/expert_dashboard_screen.dart';
import 'package:cots_monitor/features/expert/screens/expert_notifications_screen.dart';
import 'package:cots_monitor/features/expert/models/expert_action_item.dart';
import 'package:cots_monitor/models/user_model.dart';
import 'package:cots_monitor/services/site_levels_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 1400.0]) {
    testWidgets('dashboard uses real site data and routes at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final actions = ExpertActionsController(
          records: () => Stream.value([]),
          reassignments: () => Stream.value([]),
          supabase: false,
          refreshEvery: null)
        ..start();
      addTearDown(actions.dispose);
      ExpertActionPlace? opened;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ExpertDashboardScreen(
        actions: actions,
        onOpen: (value) => opened = value,
        loadUsers: () async => <UserModel>[],
        loadDecisions: () async => [],
        now: DateTime.utc(2026, 11, 10),
        siteLevels: (_) async => const [
          SiteLevel(
              areaCode: 'S4',
              areaName: 'Site 4 · Balet',
              level: 'High',
              confirmedCots: 101),
          SiteLevel(areaCode: 'S1', areaName: 'Site 1 · Tambo'),
          SiteLevel(areaCode: 'P1', areaName: 'Practice · Home', level: 'High'),
        ],
      ))));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
          find.byKey(const ValueKey('expert-dashboard-coverage')));
      await tester.tap(find.byKey(const ValueKey('expert-dashboard-coverage')));
      expect(opened, ExpertActionPlace.reassignments);
      await tester.ensureVisible(find.text('Monthly site overview'));
      expect(find.text('Practice · Home'), findsNothing);
      expect(find.text('101'), findsOneWidget);
      expect(find.text('No reports'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
