import 'package:cots_monitor/features/admin/screens/admin_zones_screen.dart';
import 'package:cots_monitor/features/admin/widgets/admin_data_table.dart';
import 'package:cots_monitor/features/admin/widgets/admin_stat_card.dart';
import 'package:cots_monitor/models/activity_type.dart';
import 'package:cots_monitor/models/capture_model.dart';
import 'package:cots_monitor/models/davao_gulf_geography.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/models/zone_directory_summary.dart';
import 'package:cots_monitor/widgets/monitoring_analytics_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/map_test_data.dart';

ScanRecordModel report(String id, String zone,
        {double confidence = 0.90,
        int count = 2,
        DateTime? date,
        String activity = CotsActivityType.detectionOnly}) =>
    ScanRecordModel(
      id: id,
      uid: 'fixture',
      submittedBy: 'Diver',
      imageName: '',
      imagePath: '',
      activityType: activity,
      aiDetectedCount: count,
      confidence: confidence,
      captureSource: 'camera',
      zone: zone,
      notes: '',
      submittedAt: date,
    );

void main() {
  setUpAll(loadTestMap);
  testWidgets('admin analytics counts site aliases once and keeps site wording',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: MonitoringAnalyticsPanel(
        useSiteTerminology: true,
        now: DateTime(2026, 11, 6),
        recordsStream: Stream.value([
          report('site-code', 'S1', date: DateTime(2026, 11, 5)),
          report('site-name', 'Site 1 · Tambo', date: DateTime(2026, 11, 5)),
          report('second-site', 'S2', date: DateTime(2026, 11, 5)),
        ]),
      ),
    ))));
    await tester.pumpAndSettle();
    final card = find
        .ancestor(
            of: find.text('Sites with records'),
            matching: find.byType(Container))
        .first;
    expect(find.descendant(of: card, matching: find.text('2')), findsOneWidget);
    expect(find.text('All sites'), findsOneWidget);
    expect(find.text('Confirmed COTS by site'), findsOneWidget);
    expect(find.text('Zones with records'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test(
      'directory lists the Samal zone and its 3 sites with no fabricated reports',
      () {
    final rows = ZoneDirectorySummary.fromRecords([]);
    expect(rows.length, DavaoGulfGeography.municipalities.length);
    expect(rows.first.zone.zoneLabel, 'Samal');
    expect(rows.last.zone.zoneLabel, 'Practice');
    expect(rows.fold<int>(0, (n, row) => n + row.zone.areas.length), 6);
    expect(rows.every((row) => row.reports == 0 && row.latestReport == null),
        isTrue);
  });
  test(
      'groups captures across stored label formats and excludes removal-only records',
      () {
    final earlier = DateTime(2026, 10, 20, 10);
    final later = DateTime(2026, 11, 1, 14, 30);
    final first = report('a', 'Site 1 · Tambo', date: earlier);
    final rows = ZoneDirectorySummary.fromRecords([
      first,
      first,
      report('b', 'S2', confidence: 0.60, count: 3, date: later),
      report('c', 'Samal', count: 1),
      report('removal', 'Site 3 · Linosutan',
          count: 99, activity: CotsActivityType.removalActivity),
      report('unknown', 'Unassigned'),
    ]);
    final samal = rows.firstWhere((row) => row.zone.zoneLabel == 'Samal');
    expect(samal.reports, 3);
    expect(samal.latestReport, later);
    expect(samal.analytics.accepted, 3);
    expect(samal.analytics.pendingRecords, 1);
    expect(samal.analytics.pending, 3);
  });
  test('Supabase site ID takes precedence over display name', () {
    const capture = CaptureModel(
        id: 'site',
        uid: 'fixture',
        submittedBy: '',
        imageName: '',
        aiDetectedCount: 0,
        confidence: 0,
        captureSource: '',
        zone: 'Adecor',
        notes: '',
        submittedAt: null,
        monitoringAreaId: 'S2');
    expect(
        ZoneDirectorySummary.zoneCodeFor(ScanRecordModel.fromCapture(capture)),
        'SAMAL');
    expect(ZoneDirectorySummary.zoneCodeFor(report('u', 'Davao City')), isNull);
    expect(ZoneDirectorySummary.zoneCodeFor(report('old', 'Zone A · A1-1')),
        isNull);
    expect(ZoneDirectorySummary.zoneCodeFor(report('unknown', 'Unassigned')),
        isNull);
  });

  test(
      'site breakdown keeps reports separate and does not invent a site for zone-only records',
      () {
    final capture = report('one', 'S1');
    final rows = SiteDirectorySummary.fromRecords([
      capture,
      capture,
      report('two', 'Site 2 · Adecor'),
      report('three', 'S3', confidence: 0.6),
      report('zone-only', 'Samal'),
      report('practice', 'P1'),
      report('removal', 'S1', activity: CotsActivityType.removalActivity),
    ]);
    expect(rows.map((row) => row.site.id), ['S1', 'S2', 'S3', 'S4', 'P1', 'P2']);
    expect(rows.map((row) => row.reports), [1, 1, 1, 0, 1, 0]);
    expect(rows[2].analytics.pendingRecords, 1);
    expect(SiteDirectorySummary.siteIdFor(report('unknown', 'Samal')), isNull);
    const source = CaptureModel(
        id: 'source',
        uid: 'fixture',
        submittedBy: '',
        imageName: '',
        aiDetectedCount: 0,
        confidence: 0,
        captureSource: '',
        zone: 'Site 1 · Tambo',
        notes: '',
        submittedAt: null,
        monitoringAreaId: 'S2');
    expect(SiteDirectorySummary.siteIdFor(ScanRecordModel.fromCapture(source)),
        'S2');
  });

  for (final width in [360.0, 1400.0]) {
    testWidgets('site selector, report filters and sorting work at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final records = [
        report('a', 'S1', count: 1, date: DateTime(2026, 11, 1)),
        report('b', 'S1', count: 1, date: DateTime(2026, 11, 2)),
        report('c', 'S2', count: 5, date: DateTime(2026, 11, 5)),
        report('d', 'S3', confidence: 0.6, date: DateTime(2026, 11, 4)),
      ];
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: AdminZonesScreen(recordsStream: Stream.value(records)))));
      await tester.pumpAndSettle();
      List<String> names() => tester
          .widgetList<Text>(find.descendant(
              of: find.byType(AdminDataTableStaticRow),
              matching: find.byType(Text)))
          .map((text) => text.data ?? '')
          .where((text) =>
              text.startsWith('Site ') || text.startsWith('Practice ·'))
          .toList();
      expect(names(), [
        'Site 1 · Tambo',
        'Site 2 · Adecor',
        'Site 3 · Linosutan',
        'Site 4 · Balet',
        'Practice · Home',
        'Practice · DNSC'
      ]);
      expect(find.byType(AdminStatCard), findsNWidgets(4));
      final siteCards =
          tester.widgetList<AdminStatCard>(find.byType(AdminStatCard));
      expect(siteCards.singleWhere((card) => card.title == 'Total sites').value,
          '6');
      expect(
          siteCards.singleWhere((card) => card.title == 'Practice sites').value,
          '2');
      expect(find.text('Total zones'), findsNothing);
      for (final entry in {
        'Most reports': 'Site 1 · Tambo',
        'Most confirmed COTS': 'Site 2 · Adecor',
        'Most pending reviews': 'Site 3 · Linosutan',
        'Latest report': 'Site 2 · Adecor',
        'Site name A–Z': 'Practice · DNSC',
        'Site order': 'Site 1 · Tambo',
      }.entries) {
        final dropdown = find.byKey(const ValueKey('zone-sort'));
        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.key).last);
        await tester.pumpAndSettle();
        expect(names().first, entry.value, reason: entry.key);
      }
      final selector = find.byKey(const ValueKey('directory-site-filter'));
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Site 2 · Adecor').last);
      await tester.pumpAndSettle();
      expect(names(), ['Site 2 · Adecor']);
      await tester.ensureVisible(find.text('View site'));
      await tester.tap(find.text('View site'));
      await tester.pumpAndSettle();
      expect(find.text('Barangay Adecor · 340 ha'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('All sites').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('All report statuses'));
      await tester.tap(find.text('All report statuses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No reports').last);
      await tester.pumpAndSettle();
      expect(names(), ['Site 4 · Balet', 'Practice · Home', 'Practice · DNSC']);
      final search = find.byType(TextField);
      await tester.ensureVisible(search);
      await tester.enterText(search, 'DNSC');
      await tester.pumpAndSettle();
      expect(names(), ['Practice · DNSC']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'failed reports retain the site directory with unavailable totals',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdminZonesScreen(
                recordsStream: Stream<List<ScanRecordModel>>.error(
                    StateError('offline'))))));
    await tester.pumpAndSettle();
    expect(find.byType(AdminDataTableStaticRow), findsNWidgets(6));
    expect(find.textContaining('Could not load reports.'), findsOneWidget);
    expect(
        tester
            .widgetList<AdminStatCard>(find.byType(AdminStatCard))
            .singleWhere((card) => card.title == 'Sites with reports')
            .value,
        '—');
    expect(tester.takeException(), isNull);
  });
}
