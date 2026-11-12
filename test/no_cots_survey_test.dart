import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cots_monitor/features/user/records_page.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/models/user_model.dart';
import 'package:cots_monitor/providers/auth_provider.dart';
import 'package:cots_monitor/services/no_cots_survey_service.dart';
import 'package:provider/provider.dart';
import 'package:cots_monitor/widgets/no_cots_survey_records.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cots_monitor/services/offline_submission_service.dart';
import 'package:cots_monitor/services/supabase_follow_up_service.dart';
import 'package:cots_monitor/models/monthly_report.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('policy refusal preserves its draft and returns an actionable error',
      () async {
    final directory = await Directory.systemTemp.createTemp('no_cots_refusal');
    const reason =
        'COTS have already been reported at this site for this month. '
        'A no-COTS survey cannot be submitted.';
    var calls = 0;
    final queue = OfflineSubmissionService(
        directoryProvider: () async => directory,
        noCotsUploader: (_) async {
          calls++;
          throw const NoCotsSurveyConflict(reason);
        },
        enableAutomaticSync: false);
    try {
      await queue.initialize();
      await expectLater(
          queue.submitNoCotsSurvey(uid: 'diver', id: 'survey', params: {
            'p_area_code': 'S4',
          }),
          throwsA(isA<NoCotsSurveyConflict>()));
      expect(queue.pendingCount, 0);
      expect(queue.pendingSubmissions.single.isRefusedNoCotsSurvey, isTrue);
      expect(queue.pendingSubmissions.single.failureReason, contains(reason));
      expect(
          NoCotsSurveyConflict.matchesReason(
              queue.pendingSubmissions.single.failureReason),
          isTrue);
      await queue.syncPending();
      expect(queue.pendingCount, 0);
      expect(calls, 1);
      expect(queue.pendingSubmissions.single.failureReason, contains(reason));
    } finally {
      queue.dispose();
      await directory.delete(recursive: true);
    }
  });

  test('later COTS label is derived and does not undo visit completion', () {
    final row = <String, dynamic>{
      'id': 'survey',
      'area_code': 'S4',
      'surveyed_at': '2026-11-10T01:00:00Z',
      'cots_reported_later': true,
    };
    expect(
        NoCotsSurveyService.observation(row), contains('COTS reported later'));
    final visit = SupabaseFollowUpService.noCotsSurveyFromRow(row);
    expect(visit.cotsReportedLater, isTrue);
    expect(visit.noCotsObserved, isTrue);
    expect(visit.serverStatus, 'completed');
    expect(visit.captureIds, isEmpty);
    expect(visit.confirmedCount, isNull);
  });

  testWidgets('survey remains visible while refresh is pending or fails',
      (tester) async {
    final refresh = Completer<List<Map<String, dynamic>>>();
    var calls = 0;
    final observed = <List<Map<String, dynamic>>>[];
    final rows = <Map<String, dynamic>>[
      {'id': 'survey', 'area_name': 'Balet'}
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NoCotsSurveyRecords(
      loader: ({required mineOnly}) {
        calls++;
        return calls == 1 ? Future.value(rows) : refresh.future;
      },
      onLoaded: observed.add,
    ))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Balet'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 2);
    expect(find.textContaining('Balet'), findsOneWidget);
    refresh.completeError(const SocketException('offline'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Balet'), findsOneWidget);
    expect(find.text('Survey records unavailable'), findsOneWidget);
    expect(observed, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('new survey precedes older photos and survives record refresh',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final records = StreamController<List<ScanRecordModel>>();
    addTearDown(records.close);
    final photos = [
      for (var i = 0; i < 10; i++)
        ScanRecordModel(
          id: 'old-$i',
          uid: 'diver',
          submittedBy: 'Diver',
          imageName: '',
          imagePath: '',
          activityType: 'detection_only',
          aiDetectedCount: 1,
          confidence: .9,
          captureSource: 'camera',
          zone: 'Balet',
          notes: '',
          submittedAt: DateTime.utc(2026, 11, 1),
        )
    ];
    var loads = 0;
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => _SurveyAuth()),
          ChangeNotifierProvider<OfflineSubmissionService>(
              create: (_) =>
                  OfflineSubmissionService(enableAutomaticSync: false)),
        ],
        child: MaterialApp(
            home: RecordsPage(
          recordsStream: records.stream,
          surveyLoader: ({required mineOnly}) async {
            loads++;
            return [
              {
                'id': 'survey',
                'area_name': 'Site 4 · Balet',
                'submitted_at': '2026-11-10T01:00:00Z',
                'surveyed_at': '2026-11-10T01:00:00Z',
                'cots_reported_later': true
              }
            ];
          },
        ))));
    records.add(photos);
    await tester.pumpAndSettle();
    expect(find.text('Survey · Site 4 · Balet'), findsOneWidget);
    expect(
        find.textContaining('COTS reported later this month'), findsOneWidget);
    records.add(photos);
    await tester.pumpAndSettle();
    expect(find.text('Survey · Site 4 · Balet'), findsOneWidget);
    expect(loads, 1);
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    scroll.position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(loads, 1);
    expect(find.text('Survey · Site 4 · Balet'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('absence survey survives restart with original GPS and no image/model',
      () async {
    final directory = await Directory.systemTemp.createTemp('no_cots_queue');
    var online = false;
    final params = <String, dynamic>{
      'p_id': 'survey-1',
      'p_area_code': 'S4',
      'p_surveyed_at': '2026-11-10T01:00:00Z',
      'p_latitude': 7.0,
      'p_longitude': 125.7,
      'p_area_m2': 200,
      'p_confirmed': true
    };
    Future<void> upload(Map<String, dynamic> task) async {
      expect(task['survey_params'], params);
      expect(task.containsKey('detection'), isFalse);
      if (!online) throw const SocketException('offline');
    }

    final first = OfflineSubmissionService(
        directoryProvider: () async => directory,
        noCotsUploader: upload,
        enableAutomaticSync: false);
    final second = OfflineSubmissionService(
        directoryProvider: () async => directory,
        noCotsUploader: upload,
        enableAutomaticSync: false);
    try {
      await first.initialize();
      expect(
          await first.submitNoCotsSurvey(
              uid: 'diver', id: 'survey-1', params: params),
          isTrue);
      expect(first.pendingCount, 1);
      expect(first.pendingSubmissions.single.name, 'No COTS observed survey');
      expect(first.pendingSubmissions.single.surveyParams, params);
      expect(
          directory
              .listSync(recursive: true)
              .whereType<File>()
              .any((f) => f.path.endsWith('.jpg')),
          isFalse);
      first.dispose();
      await second.initialize();
      await second.setActiveUser('another-diver');
      expect(second.pendingCount, 0);
      online = true;
      await second.setActiveUser('diver');
      expect(second.pendingCount, 0);
    } finally {
      second.dispose();
      await directory.delete(recursive: true);
    }
  });

  test('absence is a completed monthly visit with no invented capture or level',
      () {
    final visit = SupabaseFollowUpService.noCotsSurveyFromRow({
      'id': 's1',
      'area_code': 'S4',
      'owner_id': 'diver',
      'surveyed_at': '2026-11-10T01:00:00Z',
      'submitted_at': '2026-11-10T02:00:00Z',
      'surveyed_area_m2': 150,
      'latitude': 7.0,
      'longitude': 125.7,
    });
    expect(visit.noCotsObserved, isTrue);
    expect(visit.serverStatus, 'completed');
    expect(visit.captureIds, isEmpty);
    expect(visit.calculatedLevel, isNull);
    expect(visit.areaId, 'S4');
    expect(visit.latitude, 7.0);
  });

  test('survey-only monthly reports are exportable without COTS totals', () {
    final report =
        MonthlyReport.fromJson({'month': '2026-11-01', 'no_cots_surveys': 1});
    expect(report.isEmpty, isFalse);
    expect(report.confirmedCots, 0);
    expect(report.records, 0);
    expect(report.footnote, contains('Diver-reported no-COTS surveys: 1'));
  });
  testWidgets(
      'survey details have GPS and provenance without AI or approval controls',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showNoCotsSurveyDetails(context, {
                          'area_name': 'Site 4 · Balet',
                          'submitted_by': 'Diver',
                          'surveyed_at': '2026-11-10T01:00:00Z',
                          'submitted_at': '2026-11-10T02:00:00Z',
                          'latitude': 7.0,
                          'longitude': 125.7,
                          'gps_accuracy_m': 5,
                          'surveyed_area_m2': 200,
                          'notes': 'No COTS observed while surveying.',
                        }),
                    child: const Text('Open survey'))))));
    await tester.tap(find.text('Open survey'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Diver-reported'), findsOneWidget);
    expect(find.textContaining('Phone GPS: 7.0, 125.7'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Detection Image'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _SurveyAuth extends ChangeNotifier implements AuthProvider {
  @override
  bool get usesSupabase => true;
  @override
  UserModel get userModel => const UserModel(
      uid: 'diver',
      fullName: 'Diver',
      email: '',
      phoneNumber: '',
      role: 'Diver',
      organization: '',
      assignedArea: '',
      createdAt: null,
      profileImage: '',
      isActive: true);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
