import 'package:cots_monitor/features/admin/layout/admin_responsive_chrome.dart';
import 'package:cots_monitor/features/admin/screens/admin_shell_screen.dart';
import 'package:cots_monitor/providers/admin_record_review_tracker.dart';
import 'package:cots_monitor/services/scan_record_repository.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/widgets/monitoring_analytics_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('desktop AdminShellScreen supplies a normal page surface',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final token = ScanRecordRepository.windowsIdToken;
    ScanRecordRepository.setWindowsIdToken(null);
    addTearDown(() => ScanRecordRepository.setWindowsIdToken(token));
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AdminRecordReviewTracker(),
      child: const MaterialApp(home: AdminShellScreen()),
    ));
    await tester.pumpAndSettle();
    final subtitle = find.text('Live summaries from saved monitoring records.');
    expect(subtitle, findsOneWidget);
    expect(DefaultTextStyle.of(tester.element(subtitle)).style.fontSize,
        lessThan(24));
    expect(find.byType(Scaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [800.0, 1400.0]) {
    testWidgets('actual admin layout supports Dashboard dropdowns at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // No outer Scaffold: the production responsive layout must supply it.
      await tester.pumpWidget(MaterialApp(
        home: AdminResponsiveChrome(
          selectedNavIndex: 0,
          onNavSelect: (_) {},
          onLogout: () {},
          pageTitle: 'Dashboard Overview',
          body: SingleChildScrollView(
            child: MonitoringAnalyticsPanel(
              recordsStream: Stream.value(const <ScanRecordModel>[]),
              now: DateTime(2026, 11, 1),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final daily = find.text('Daily');
      await tester.ensureVisible(daily);
      await tester.tap(daily);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly').last);
      await tester.pumpAndSettle();
      expect(find.text('Weekly'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
