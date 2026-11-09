import 'dart:io';

import 'package:cots_monitor/models/activity_type.dart';
import 'package:cots_monitor/models/capture_model.dart';
import 'package:cots_monitor/models/cots_detection_result.dart';
import 'package:cots_monitor/models/cots_tally.dart';
import 'package:cots_monitor/models/monitoring_analytics.dart';
import 'package:cots_monitor/models/record_collection.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/services/scan_record_repository.dart';
import 'package:cots_monitor/widgets/monitoring_analytics_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stage 3 (claude/agreed_workflow_decisions.md): honest reports.
List<CotsBoundingBox> _boxes(int n) => [
      for (var i = 0; i < n; i++)
        CotsBoundingBox(
            x1: i * 20.0, y1: 0, x2: i * 20.0 + 10, y2: 10, score: 0.9),
    ];

ScanRecordModel _supabasePhoto(String id,
        {int ai = 5, int? confirmed = 3, int? waiting = 1}) =>
    ScanRecordModel.fromCapture(CaptureModel(
      id: id,
      uid: 'diver-a',
      submittedBy: 'Diver Alpha',
      imageName: '$id.jpg',
      aiDetectedCount: ai,
      confidence: 0.9,
      captureSource: 'GoPro Underwater Image',
      zone: 'Reef A',
      notes: '',
      submittedAt: DateTime(2026, 10, 22, 9),
      detectionBoxes: _boxes(ai),
      imageWidth: 640,
      imageHeight: 480,
      confirmedCount: confirmed,
      waitingCount: waiting,
    ));

ScanRecordModel _removalRow(String id, String linkedCaptureId) =>
    ScanRecordModel(
      id: id,
      uid: 'diver-a',
      submittedBy: 'Diver Alpha',
      imageName: '',
      imagePath: '',
      activityType: CotsActivityType.removalActivity,
      aiDetectedCount: 5,
      confidence: 0.9,
      captureSource: 'GoPro Underwater Image',
      zone: 'Reef A',
      notes: '',
      submittedAt: DateTime(2026, 10, 22, 9),
      removedQuantity: 5,
      recordCollection: RecordCollection.removalRecords,
      linkedCaptureId: linkedCaptureId,
    );

void main() {
  test('agreed report wording', () {
    expect(HonestReport.confirmedLabel, 'COTS found and removed (confirmed)');
    expect(HonestReport.waitingLabel, 'Waiting for Expert');
    expect(HonestReport.notAcceptedLabel, 'Not accepted');
  });

  test('a photo uses the database numbers; the three parts add up', () {
    final tally = _supabasePhoto('cap-1').cotsTally;
    expect(tally.confirmed, 3);
    expect(tally.waiting, 1);
    expect(tally.notAccepted, 1);
    expect(tally.total, 5);
  });

  test('another Diver\'s waiting record counts 0 confirmed', () {
    final data = MonitoringAnalytics.fromRecords(
        [_supabasePhoto('cap-2', ai: 2, confirmed: 0, waiting: 2)]);
    expect(data.accepted, 0);
    expect(data.pending, 2);
    expect(data.pendingRecords, 1);
    expect(data.byZone['Reef A'], 0);
    expect(
        data
            .trend(DateTime(2026, 10, 22), DateTime(2026, 10, 22), 'Daily')
            .single
            .count,
        0);
  });

  test('removal records add no COTS of their own', () {
    expect(_removalRow('elim-1', 'cap-1').cotsTally.total, 0);
  });

  test('an encounter\'s removal record is shown on its first photo\'s row',
      () {
    final photo = _supabasePhoto('cap-1');
    final removal = _removalRow('elim-1', 'cap-1');
    final merged = ScanRecordRepository.mergeCaptureRemovalRecords(
        [photo], [removal],
        pairByLinkedCapture: true);
    expect(merged, hasLength(1));
    expect(merged.single.id, 'cap-1');
    expect(CotsActivityType.isRemoval(merged.single.activityType), isTrue);
    expect(merged.single.cotsTally.confirmed, 3);
    final data = MonitoringAnalytics.fromRecords(merged);
    expect(data.accepted, 3);
    expect(data.removalRecords, hasLength(1));
    // Firebase keeps its own pairing (historical separate removals).
    expect(
        ScanRecordRepository.mergeCaptureRemovalRecords([photo], [removal]),
        hasLength(2));
  });

  test('removal methods: three main rows, older methods grouped as Other', () {
    final grouped = RemovalMethodCount.group(const [
      RemovalMethodCount(method: 'Vinegar Injection', cots: 4, removals: 2),
      RemovalMethodCount(
          method: 'Ox Bile / Bile Salts Injection', cots: 2, removals: 1),
      RemovalMethodCount(method: 'Community Cleanup', cots: 1, removals: 1),
      RemovalMethodCount(method: 'Research Collection', cots: 2, removals: 1),
      RemovalMethodCount(method: 'Injection Method', cots: 1, removals: 1),
      RemovalMethodCount(method: 'manual removal', cots: 3, removals: 2),
    ]);
    expect([for (final row in grouped) row.method], [
      RemovalMethodCount.manualLabel,
      RemovalMethodCount.vinegarLabel,
      RemovalMethodCount.oxBileLabel,
      RemovalMethodCount.otherLabel,
    ]);
    expect(grouped.last.cots, 4);
    expect(grouped.last.removals, 3);
    expect(grouped.first.cots, 3);
  });

  testWidgets('Analytics shows the removal-method pie with its numbers',
      (tester) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MonitoringAnalyticsPanel(
      recordsStream: Stream.value([_supabasePhoto('cap-1')]),
      now: DateTime(2026, 10, 22),
      removalMethodLoader: (from, to, zone) async => const [
        RemovalMethodCount(method: 'Manual Removal', cots: 2, removals: 1),
        RemovalMethodCount(method: 'Vinegar Injection', cots: 1, removals: 1),
        RemovalMethodCount(
            method: 'Ox Bile / Bile Salts Injection', cots: 1, removals: 1),
      ],
    )))));
    await tester.pumpAndSettle();
    expect(find.text('Removal methods'), findsOneWidget);
    expect(find.text('Manual removal: 2 COTS · 50% · 1 removal'),
        findsOneWidget);
    expect(find.text('Vinegar injection: 1 COTS · 25% · 1 removal'),
        findsOneWidget);
    expect(find.text('Ox bile injection: 1 COTS · 25% · 1 removal'),
        findsOneWidget);
    expect(find.textContaining('repeated sightings'), findsNothing);
    expect(find.textContaining('Reported eliminated quantity'), findsNothing);
    expect(find.textContaining('unavailable without a verified area survey'),
        findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('the database update provides the numbers the app reads', () {
    final sql = File('supabase/migrations/20261031000300_honest_reports.sql')
        .readAsStringSync();
    expect(sql, contains('function public.confirmed_cots(c public.captures)'));
    expect(sql, contains('function public.waiting_cots(c public.captures)'));
    expect(sql, contains('function public.removal_method_summary('));
  });
}
