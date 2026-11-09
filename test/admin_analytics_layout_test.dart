import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cots_monitor/widgets/monitoring_analytics_panel.dart';
import 'package:cots_monitor/widgets/monthly_site_levels_card.dart';
import 'package:cots_monitor/services/site_levels_service.dart';
import 'package:cots_monitor/core/user_shell_theme.dart'
    show kLow, kModerate, kHigh;
import 'monitoring_analytics_test.dart' as fixtures;
import 'support/map_test_data.dart';

void main() {
  setUpAll(loadTestMap);
  for (final size in [
    (320.0, 1.0),
    (800.0, 1.0),
    (1400.0, 1.0),
    (320.0, 2.0)
  ]) {
    testWidgets('admin analytics arranges charts responsively at $size',
        (tester) async {
      tester.view.physicalSize = Size(size.$1, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(size.$2)),
              child: child!),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: MonitoringAnalyticsPanel(
                          dashboardLayout: true,
                          useSiteTerminology: true,
                          now: DateTime(2026, 11, 8),
                          recordsStream: Stream.value([
                            fixtures.record('a',
                                zone: 'Site 4 · Balet',
                                date: DateTime(2026, 11, 8))
                          ]),
                          removalMethodLoader: (from, to, site) async =>
                              const []))))));
      await tester.pumpAndSettle();
      final trend = tester.getTopLeft(find.text('Confirmed COTS trend'));
      final sites = tester.getTopLeft(find.text('Confirmed COTS by site'));
      if (size.$1 >= 1000) {
        expect(trend.dy, sites.dy);
        expect(sites.dx, greaterThan(trend.dx));
      } else {
        expect(sites.dy, greaterThan(trend.dy));
      }
      expect(find.byKey(const ValueKey('metric-Overall confidence')),
          findsOneWidget);
      expect(find.text('Average across individual COTS detections.'),
          findsNothing);
      final metric =
          find.byKey(const ValueKey('analytics-info-Overall confidence'));
      await tester.ensureVisible(metric);
      await tester.pumpAndSettle();
      await tester.tap(metric);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Average across individual COTS detections.'),
          findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('monthly table retains real level colors and no-data states',
      (tester) async {
    final month = DateTime.now();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MonthlySiteLevelsCard(
                    history: () async => [
                          for (final entry in [
                            ('S1', 'Low', 1),
                            ('S2', 'Moderate', 20),
                            ('S3', 'High', 110)
                          ])
                            SiteLevel.fromJson({
                              'area_code': entry.$1,
                              'level': entry.$2,
                              'month':
                                  '${month.year}-${month.month.toString().padLeft(2, '0')}-01',
                              'confirmed_cots': entry.$3
                            })
                        ])))));
    await tester.pumpAndSettle();
    for (final color in [kLow, kModerate, kHigh]) {
      expect(
          find.byWidgetPredicate((widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).border ==
                  Border.all(color: color)),
          findsWidgets);
    }
    expect(find.text('—'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
