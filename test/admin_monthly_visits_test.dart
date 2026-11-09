import 'package:cots_monitor/features/admin/widgets/admin_monthly_visits_view.dart';
import 'package:cots_monitor/models/follow_up_monitoring_model.dart';
import 'package:cots_monitor/services/monthly_visits_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FollowUpAssignmentModel _site(String code, String name, DateTime assigned) =>
    FollowUpAssignmentModel(
      areaId: code,
      areaName: name,
      barangay: '',
      municipality: '',
      primaryDiverUid: 'd-$code',
      primaryDiverName: 'Diver $code',
      initialCaptureId: 'c-$code',
      initialDate: assigned,
      initialDetectedCount: 1,
    );

FollowUpSurveyModel _visit(String id, String code, String name, DateTime day,
        {String status = 'completed', int confirmed = 4, int waiting = 0}) =>
    FollowUpSurveyModel(
      id: id,
      areaId: code,
      uid: 'd-$code',
      submittedBy: 'Megan',
      areaName: name,
      barangay: '',
      municipality: '',
      surveyDate: day,
      fieldObservedCount: 5,
      fieldEliminatedCount: 0,
      captureIds: const ['p1'],
      submittedAt: day,
      serverStatus: status,
      confirmedCount: confirmed,
      waitingCount: waiting,
    );

MonthlyVisitsData _data() => MonthlyVisitsData(
      assignments: [
        _site('S1', 'Site 1', DateTime(2026, 9, 2)),
        _site('S3', 'Site 3', DateTime(2026, 10, 5)),
        _site('S4', 'Site 4', DateTime(2026, 12, 1)),
      ],
      surveys: [
        _visit('v1', 'S1', 'Site 1', DateTime(2026, 11, 3)),
        _visit('v2', 'S1', 'Site 1', DateTime(2026, 10, 3),
            status: 'pending', waiting: 2),
      ],
    );

void main() {
  test('a month lists visits and assigned sites with no visit', () {
    final rows = _data().rowsFor(DateTime(2026, 11));
    expect(rows.map((r) => r.siteName), ['Site 1', 'Site 3']);
    expect(rows.first.statusLabel, 'Completed');
    expect(rows.first.cotsCounted, 4);
    expect(rows.last.missing, isTrue);
    expect(rows.last.statusLabel, 'No visit');
    expect(rows.last.diverName, 'Diver S3');
  });

  test('sites assigned after the month are not listed as missing', () {
    final rows = _data().rowsFor(DateTime(2026, 9));
    expect(rows.map((r) => r.siteName), ['Site 1']);
    expect(rows.single.missing, isTrue);
  });

  test('all months shows only real visits, newest first', () {
    final rows = _data().rowsFor(null);
    expect(rows.map((r) => r.survey!.id), ['v1', 'v2']);
    expect(rows.last.statusLabel, 'Waiting for Expert');
    expect(rows.last.waiting, 2);
  });

  test('site filter keeps one site', () {
    final rows = _data().rowsFor(DateTime(2026, 11), site: 'Site 3');
    expect(rows.single.siteName, 'Site 3');
  });

  testWidgets('tab shows visits, missing sites and details', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AdminMonthlyVisitsView(
            load: () async => _data(),
            now: DateTime(2026, 11, 8),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Site 1'), findsOneWidget);
    expect(find.text('Site 3'), findsOneWidget);
    expect(find.text('No visit'), findsOneWidget);
    expect(find.text('1 visit · 1 site with no visit'), findsOneWidget);
    await tester.tap(find.text('Site 1'));
    await tester.pumpAndSettle();
    expect(find.text('Monthly visit'), findsOneWidget);
    expect(find.text('COTS confirmed'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a load error offers retry', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminMonthlyVisitsView(
          load: () async => throw Exception('offline'),
          now: DateTime(2026, 11, 8),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Could not load monthly visits.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
