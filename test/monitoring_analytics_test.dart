import 'dart:async';

import 'package:cots_monitor/models/activity_type.dart';
import 'package:cots_monitor/models/cots_confidence_policy.dart';
import 'package:cots_monitor/models/cots_detection_result.dart';
import 'package:cots_monitor/models/monitoring_analytics.dart';
import 'package:cots_monitor/models/record_collection.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/features/user/user_dashboard_analytics.dart';
import 'package:cots_monitor/widgets/monitoring_analytics_panel.dart';
import 'package:cots_monitor/widgets/cots_loading_skeleton.dart';
import 'package:cots_monitor/features/admin/widgets/recent_submissions_table_card.dart';
import 'package:cots_monitor/features/user/dashboard_screen.dart';
import 'package:cots_monitor/providers/auth_provider.dart';
import 'package:cots_monitor/models/user_model.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ScanRecordModel record(String id,
        {List<double> scores = const [.9, .4],
        String zone = 'Reef A',
        DateTime? date,
        String collection = RecordCollection.captures,
        bool removal = false,
        int? eliminated,
        bool rejected = false,
        String? linkedCaptureId,
        List<PerCotsAdminDecision> decisions = const []}) =>
    ScanRecordModel(
      id: id,
      uid: 'diver',
      submittedBy: 'Diver',
      imageName: '$id.jpg',
      imagePath: '',
      activityType: removal
          ? CotsActivityType.removalActivity
          : CotsActivityType.detectionOnly,
      aiDetectedCount: scores.length,
      confidence:
          scores.isEmpty ? 0 : scores.reduce((a, b) => a + b) / scores.length,
      captureSource: 'GoPro Image',
      zone: zone,
      notes: '',
      submittedAt: date ?? DateTime(2026, 10, 22, 23, 59),
      recordCollection: collection,
      removedQuantity: eliminated,
      adminRejected: rejected,
      linkedCaptureId: linkedCaptureId,
      adminCotsDecisions: decisions,
      imageWidth: 100,
      imageHeight: 100,
      detectionBoxes: [
        for (final score in scores)
          CotsBoundingBox(x1: 0, y1: 0, x2: 10, y2: 10, score: score)
      ],
    );

void main() {
  test('unmerged removal evidence is retained and merged companions count once',
      () {
    final evidence = record('a_removal',
        collection: RecordCollection.removalRecords,
        removal: true,
        eliminated: 3,
        linkedCaptureId: 'a');
    final separate = MonitoringAnalytics.fromRecords([record('a'), evidence]);
    expect(separate.removalRecords, hasLength(1));
    expect(separate.reportedEliminated, 3);
    final merged = MonitoringAnalytics.fromRecords(
        [record('a', removal: true, eliminated: 3), evidence]);
    expect(merged.removalRecords, hasLength(1));
    expect(merged.reportedEliminated, 3);
  });
  test(
      'observations exclude duplicate snapshots, evidence and survey summaries',
      () {
    final capture = record('a', removal: true);
    final data = MonitoringAnalytics.fromRecords([
      capture,
      capture,
      record('evidence',
          collection: RecordCollection.removalRecords,
          removal: true,
          eliminated: 3),
      record('survey', collection: RecordCollection.followUpSurveys),
    ]);
    expect(data.totalCots, 2);
    expect(data.captures, hasLength(1));
    expect(data.accepted, 1);
    expect(data.pending, 1);
    expect(data.averageConfidence, 65);
    expect(data.confidenceBands[CotsVerificationBand.aiAutoApproved.index], 1);
    expect(data.reportedEliminated, 3);
    expect(data.unreportedRemovals, 1);
    expect(data.removalRecords, hasLength(2));
  });
  test('Expert decisions update status without changing confidence bands', () {
    final data = MonitoringAnalytics.fromRecords([
      record('a', decisions: [
        PerCotsAdminDecision.confirmed,
        PerCotsAdminDecision.rejected
      ])
    ]);
    expect(data.accepted, 1);
    expect(data.rejected, 1);
    expect(data.pending, 0);
    expect(data.pendingRecords, 0);
    expect(data.confidenceBands[CotsVerificationBand.adminReview.index], 1);
  });
  test('date and zone filters, including end-of-day, apply to trend and totals',
      () {
    final records = [
      record('a'),
      record('b', zone: 'Reef B'),
      record('c', date: DateTime(2026, 10, 21)),
      record('d', date: DateTime(2026, 10, 23))
    ];
    final data = MonitoringAnalytics.fromRecords(records,
        from: DateTime(2026, 10, 22),
        to: DateTime(2026, 10, 22),
        zone: 'Reef A');
    expect(data.totalCots, 2);
    for (final mode in ['Daily', 'Weekly', 'Monthly']) {
      expect(
          data
              .trend(DateTime(2026, 10, 22), DateTime(2026, 10, 22), mode)
              .single
              .count,
          2);
    }
  });
  test(
      'empty analytics has zero observations and no invented confidence or trends',
      () {
    final data = MonitoringAnalytics.fromRecords([]);
    expect(data.totalCots, 0);
    expect(data.averageConfidence, isNull);
    final dashboard =
        UserDashboardAnalytics.fromRecords([], now: DateTime(2026, 10, 22));
    expect(dashboard.totalCots, 0);
    expect(dashboard.totalScans, 0);
    expect(dashboard.lastUpdated, isNull);
    expect(dashboard.dailyTrendValues, everyElement(0));
    expect(dashboard.scansTrendPct, isNull);
  });

  for (final layout in [(320.0, 1.0), (320.0, 2.0), (1200.0, 1.0)]) {
    final scale = layout.$2;
    testWidgets(
        'live analytics handles empty data, updates and errors at $layout',
        (tester) async {
      tester.view.physicalSize = Size(layout.$1, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = StreamController<List<ScanRecordModel>>();
      addTearDown(controller.close);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: MonitoringAnalyticsPanel(
                      recordsStream: controller.stream,
                      now: DateTime(2026, 10, 22))))));
      expect(find.byType(CotsLoadingSkeleton), findsOneWidget);
      controller.add([]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('analytics-empty')), findsOneWidget);
      expect(find.byType(CotsLoadingSkeleton), findsNothing);
      expect(
          tester
              .widget<Text>(
                  find.byKey(const ValueKey('metric-Total COTS detections')))
              .data,
          '0');
      controller.add([record('a')]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('analytics-empty')), findsNothing);
      expect(
          tester
              .widget<Text>(
                  find.byKey(const ValueKey('metric-Total COTS detections')))
              .data,
          '2');
      controller.add([
        record('a'),
        record('b', zone: 'Reef B', scores: [.9, .8, .7])
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reef B').last);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<Text>(
                  find.byKey(const ValueKey('metric-Total COTS detections')))
              .data,
          '3');
      controller.addError(StateError('connection lost'));
      await tester.pumpAndSettle();
      expect(find.text('Analytics unavailable'), findsOneWidget);
      expect(find.byKey(const ValueKey('metric-Total COTS detections')),
          findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('Diver dashboard loads saved records at $layout',
        (tester) async {
      tester.view.physicalSize = Size(layout.$1, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = _SignedOutAuth();
      addTearDown(auth.dispose);
      final dashboardRecords = StreamController<List<ScanRecordModel>>();
      addTearDown(dashboardRecords.close);
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: DashboardScreen(recordsStream: dashboardRecords.stream))));
      expect(find.byType(CotsLoadingSkeleton), findsOneWidget);
      dashboardRecords.add([record('a')]);
      await tester.pumpAndSettle();
      expect(find.byType(CotsLoadingSkeleton), findsNothing);
      expect(find.text('Total Monitoring Captures'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('recent submissions never label rejected evidence as cleared',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: RecentSubmissionsTableCard(
                    recordsStream: Stream.value([
      record('rejected', rejected: true),
      record('pending', scores: List.filled(16, .5)),
      record('zero', scores: []),
    ]))))));
    await tester.pumpAndSettle();
    expect(find.text('Rejected / Retake'), findsOneWidget);
    expect(find.text('Pending Validation'), findsOneWidget);
    expect(find.text('No detections'), findsOneWidget);
    expect(find.text('Cleared'), findsNothing);
    expect(find.text('Intervention Required'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _SignedOutAuth extends ChangeNotifier implements AuthProvider {
  @override
  UserModel? get userModel => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
