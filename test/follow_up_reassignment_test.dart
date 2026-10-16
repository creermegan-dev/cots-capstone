import 'dart:convert';
import 'package:cots_monitor/models/follow_up_monitoring_model.dart';
import 'package:cots_monitor/models/follow_up_reassignment.dart';
import 'package:cots_monitor/models/user_model.dart';
import 'package:cots_monitor/models/capture_model.dart';
import 'package:cots_monitor/models/follow_up_infestation_assessment.dart';
import 'package:cots_monitor/services/follow_up_monitoring_repository.dart';
import 'package:cots_monitor/providers/auth_provider.dart';
import 'package:cots_monitor/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:cots_monitor/services/follow_up_reassignment_repository.dart';
import 'package:cots_monitor/services/follow_up_workflow_store.dart';
import 'package:cots_monitor/widgets/follow_up_reassignment_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

final assignment = FollowUpAssignmentModel(
    areaId: 'reef',
    areaName: 'Reef A',
    barangay: 'Barangay A',
    municipality: 'Town',
    primaryDiverUid: 'a',
    primaryDiverName: 'Diver A',
    initialCaptureId: 'initial',
    initialDate: DateTime(2026, 9, 1),
    initialDetectedCount: 40);

UserModel user(String uid) => UserModel(
    uid: uid,
    fullName: 'Diver $uid',
    email: '',
    phoneNumber: '',
    role: 'Field Monitor',
    organization: '',
    assignedArea: '',
    createdAt: null,
    profileImage: '',
    isActive: true,
    fieldPersonnelVerified: true);

class _Auth extends AuthProvider {
  _Auth(this.profile) : super(authService: _NoSessionAuth());
  final UserModel profile;
  @override
  UserModel get userModel => profile;
}

class _NoSessionAuth implements AuthService {
  @override
  Stream<User?> authStateChanges() => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> requestData(
    {String status = 'accepted', String responsible = 'b'}) {
  final ph = MonitoringMonth.local(DateTime.now());
  return {
    'area_id': 'reef',
    'area_name': 'Reef A',
    'barangay': 'Barangay A',
    'municipality': 'Town',
    'primary_uid': 'a',
    'primary_name': 'Diver A',
    'year': ph.year,
    'month': ph.month,
    'responsible_uid': responsible,
    'requester_uid': 'a',
    'reason': 'Weather',
    'status': status,
    'replacement_uid': 'b',
    'replacement_name': 'Diver B',
    'expert_uid': 'expert',
    'participants': ['a', 'b'],
    'revision': 2,
    'requested_at': DateTime.now().toUtc(),
    'updated_at': DateTime.now().toUtc()
  };
}

Map<String, dynamic> document(String path, Map<String, dynamic> data) => {
      'name': 'projects/test/databases/(default)/documents/$path',
      'updateTime': '2026-10-01T00:00:00Z',
      'fields': FollowUpWorkflowStore.fields(data),
    };

void main() {
  late FollowUpWorkflowStore original;
  setUp(() => original = FollowUpReassignmentRepository.store);
  tearDown(() => FollowUpReassignmentRepository.store = original);
  void useClient(MockClient client) {
    addTearDown(client.close);
    FollowUpReassignmentRepository.store = FollowUpWorkflowStore(
        client: client,
        projectId: 'test',
        tokenProvider: () async => 'test-token');
  }

  test('Philippine calendar boundaries are independent of device timezone', () {
    expect(MonitoringMonth.key(DateTime.utc(2026, 9, 30, 15, 59)), '2026_9');
    expect(MonitoringMonth.key(DateTime.utc(2026, 9, 30, 16)), '2026_10');
    expect(MonitoringMonth.key(DateTime.utc(2026, 10, 31, 16)), '2026_11');
    expect(surveyCalendarInstant(DateTime(2026, 10, 1)),
        DateTime.utc(2026, 9, 30, 16));
  });

  test(
      'acceptance atomically writes responsibility, audit and unique notifications',
      () async {
    final data = requestData(status: 'awaiting_acceptance', responsible: 'a');
    final id = MonitoringMonth.id('reef', DateTime.now());
    Map<String, dynamic>? committed;
    useClient(MockClient((r) async {
      expect(r.headers['Authorization'], 'Bearer test-token');
      if (r.method == 'GET') {
        return http.Response(
            jsonEncode(document('follow_up_reassignments/$id', data)), 200);
      }
      committed = jsonDecode(r.body) as Map<String, dynamic>;
      return http.Response('{}', 200);
    }));
    await FollowUpReassignmentRepository.respond(
        FollowUpReassignment(id, data), 'b', true);
    final writes = (committed!['writes'] as List).cast<Map<String, dynamic>>();
    expect(writes, hasLength(6));
    final authority = FollowUpWorkflowStore.data(writes[0]['update']);
    expect(authority['responsible_uid'], 'b');
    expect(authority['primary_uid'], 'a');
    final state = FollowUpWorkflowStore.data(writes[1]['update']);
    expect(state['status'], 'accepted');
    expect(state['primary_uid'], 'a');
    expect(
        writes[1]['currentDocument'], {'updateTime': '2026-10-01T00:00:00Z'});
    expect(
        FollowUpWorkflowStore.data(writes[2]['update'])['action'], 'accepted');
    final names =
        writes.skip(3).map((w) => w['update']['name'] as String).toSet();
    expect(names, hasLength(3));
    expect(names.every((name) => name.contains('${id}_3_')), isTrue);
  });

  test('accepted replacement area appears in the Follow-up assignment stream',
      () async {
    final data = requestData();
    useClient(MockClient((r) async {
      if (r.method == 'GET') {
        return http.Response(
            jsonEncode(document('follow_up_assignments/reef', {
              'area_id': 'reef',
              'area_name': 'Reef A',
              'barangay': 'Barangay A',
              'municipality': 'Town',
              'primary_diver_uid': 'a',
              'primary_diver_name': 'Diver A',
              'initial_capture_id': 'initial',
              'initial_date': DateTime(2026, 9, 1),
              'initial_detected_count': 40,
            })),
            200);
      }
      final query = jsonDecode(r.body)['structuredQuery'];
      final collection = query['from'][0]['collectionId'];
      return http.Response(
          jsonEncode(collection == 'follow_up_assignments'
              ? []
              : [
                  {
                    'document':
                        document('follow_up_reassignments/current', data)
                  }
                ]),
          200);
    }));
    final result =
        await FollowUpMonitoringRepository.watchAssignmentsForDiver('b').first;
    expect(result.map((a) => a.areaId), ['reef']);
    expect(result.single.primaryDiverUid, 'a');
  });

  test('a valid B survey completes October while an incomplete one does not',
      () {
    final survey = FollowUpSurveyModel(
        id: 'visit',
        areaId: 'reef',
        uid: 'b',
        submittedBy: 'Diver B',
        areaName: 'Reef A',
        barangay: 'Barangay A',
        municipality: 'Town',
        surveyDate: DateTime(2026, 10, 15),
        fieldObservedCount: 0,
        fieldEliminatedCount: 0,
        captureIds: ['evidence'],
        submittedAt: DateTime(2026, 10, 15));
    final capture = CaptureModel(
        id: 'evidence',
        uid: 'b',
        submittedBy: 'Diver B',
        imageName: 'reef.jpg',
        aiDetectedCount: 0,
        confidence: 0,
        captureSource: 'GoPro Underwater Image',
        monitoringAreaId: 'reef',
        followUpSurveyId: 'visit',
        zone: 'Reef A',
        notes: '',
        submittedAt: DateTime(2026, 10, 15));
    expect(followUpSurveyStatus(survey, []), FollowUpSurveyStatus.submitted);
    expect(followUpSurveyStatus(survey, [capture]),
        FollowUpSurveyStatus.completed);
    final history = buildFollowUpMonthHistory(
        initialDate: DateTime(2026, 9, 1),
        surveys: [survey],
        currentDate: DateTime(2026, 11, 10),
        completedSurveyIds: {survey.id});
    expect(history.firstWhere((m) => m.month.month == 10).status,
        FollowUpMonthStatus.monitored);
    expect(survey.uid, 'b');
    expect(assignment.primaryDiverUid, 'a');
  });

  test(
      'risk requires explicit validated metadata and never uses detection counts',
      () {
    expect(
        FollowUpInfestationAssessment.fromMap(
            {'ai_detected_count': 999, 'admin_confirmed': true}),
        isNull);
    expect(
        FollowUpInfestationAssessment.fromMap(
            {'validated_infestation_level': 'High'}),
        isNull);
    final assessment = FollowUpInfestationAssessment.fromMap({
      'validated_infestation_level': 'High',
      'infestation_validated_by': 'expert',
      'infestation_validated_at': DateTime(2026, 10, 16),
      'survey_date': DateTime(2026, 10, 15),
    });
    expect(assessment!.isHigh, isTrue);
  });

  test('stale response never commits or emits duplicate notifications',
      () async {
    var commits = 0;
    final data = requestData(status: 'awaiting_acceptance', responsible: 'a');
    useClient(MockClient((r) async {
      if (r.method != 'GET') commits++;
      return http.Response(
          jsonEncode(
              document('follow_up_reassignments/id', {...data, 'revision': 3})),
          200);
    }));
    await expectLater(
        FollowUpReassignmentRepository.respond(
            FollowUpReassignment('id', data), 'b', true),
        throwsStateError);
    expect(commits, 0);
  });

  test('November falls back to original diver when no November request exists',
      () async {
    useClient(MockClient((_) async => http.Response('{}', 404)));
    expect(
        await FollowUpReassignmentRepository.isResponsible(
            assignment, 'a', DateTime(2026, 11, 1)),
        isTrue);
    expect(
        await FollowUpReassignmentRepository.isResponsible(
            assignment, 'b', DateTime(2026, 11, 1)),
        isFalse);
  });

  test('accepted but incomplete survey does not mark the month monitored', () {
    final history = buildFollowUpMonthHistory(
        initialDate: DateTime(2026, 9, 1),
        surveys: [],
        currentDate: DateTime(2026, 11, 10),
        completedSurveyIds: {});
    expect(history.firstWhere((e) => e.month.month == 10).status,
        FollowUpMonthStatus.notRecorded);
  });

  testWidgets(
      'replacement must explicitly accept a proposal before it activates',
      (tester) async {
    var data = requestData(status: 'awaiting_acceptance', responsible: 'a');
    final id = MonitoringMonth.id('reef', DateTime.now());
    var commits = 0;
    useClient(MockClient((r) async {
      if (r.method == 'GET') {
        return http.Response(
            jsonEncode(document('follow_up_reassignments/$id', data)), 200);
      }
      final payload = jsonDecode(r.body);
      if (payload['writes'] != null) {
        commits++;
        final update = (payload['writes'] as List).firstWhere((w) => w['update']
                ['name']
            .toString()
            .contains('/follow_up_reassignments/'));
        data = FollowUpWorkflowStore.data(update['update']);
        return http.Response('{}', 200);
      }
      return http.Response('[]', 200);
    }));
    final auth = _Auth(user('b'));
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
        child: ReassignmentDetails(requestId: id),
      ))),
    ));
    await tester.pumpAndSettle();
    expect(data['responsible_uid'], 'a');
    expect(find.text('Accept Assignment'), findsOneWidget);
    expect(find.text('Decline Assignment'), findsOneWidget);
    await tester.tap(find.text('Accept Assignment'));
    await tester.pumpAndSettle();
    expect(data['responsible_uid'], 'b');
    expect(data['status'], 'accepted');
    expect(commits, 1);
    expect(find.text('Accept Assignment'), findsNothing);
    expect(find.text('Acceptance is separate from monitoring completion.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'unavailability form requires a reason and saves one audited request',
      (tester) async {
    Map<String, dynamic>? data;
    var commits = 0;
    final id = MonitoringMonth.id('reef', DateTime.now());
    useClient(MockClient((r) async {
      if (r.method == 'GET') return http.Response('{}', 404);
      final payload = jsonDecode(r.body);
      if (payload['writes'] != null) {
        commits++;
        data = FollowUpWorkflowStore.data(
            (payload['writes'] as List)[1]['update']);
        return http.Response('{}', 200);
      }
      return http.Response(
          jsonEncode(data == null
              ? []
              : [
                  {'document': document('follow_up_reassignments/$id', data!)}
                ]),
          200);
    }));
    final auth = _Auth(user('a'));
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
          home: Scaffold(
              body: FollowUpReassignmentActions(
        assignment: assignment,
        onStart: () {},
      ))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unavailable This Month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Request'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter a reason'), findsOneWidget);
    expect(commits, 0);
    await tester.enterText(find.byType(TextField), 'Unsafe weather conditions');
    await tester.tap(find.text('Submit Request'));
    await tester.pumpAndSettle();
    expect(commits, 1);
    expect(data!['reason'], 'Unsafe weather conditions');
    expect(data!['primary_uid'], 'a');
    expect(data!['responsible_uid'], 'a');
    expect(find.textContaining('Reassignment Requested'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Expert confirms an eligible proposal without activating it',
      (tester) async {
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var data = requestData(status: 'requested', responsible: 'a')
      ..['replacement_uid'] = ''
      ..['replacement_name'] = ''
      ..['expert_uid'] = ''
      ..['participants'] = ['a'];
    final id = MonitoringMonth.id('reef', DateTime.now());
    var commits = 0;
    useClient(MockClient((r) async {
      if (r.method == 'GET') {
        return http.Response(
            jsonEncode(document('follow_up_reassignments/$id', data)), 200);
      }
      final payload = jsonDecode(r.body);
      if (payload['writes'] != null) {
        commits++;
        data = FollowUpWorkflowStore.data(
            (payload['writes'] as List)[1]['update']);
        return http.Response('{}', 200);
      }
      final collection = payload['structuredQuery']['from'][0]['collectionId'];
      return http.Response(
          jsonEncode(collection == 'follow_up_personnel'
              ? [
                  {
                    'document': document('follow_up_personnel/b',
                        {'name': 'Diver B', 'eligible': true})
                  }
                ]
              : []),
          200);
    }));
    final auth = _Auth(user('expert').copyWith(accountRole: 'expert'));
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            home: Scaffold(
                body: MediaQuery(
                    data: const MediaQueryData(
                        textScaler: TextScaler.linear(1.5)),
                    child: SingleChildScrollView(
                        child: ReassignmentDetails(requestId: id)))))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Assign Replacement'));
    await tester.tap(find.text('Assign Replacement'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Diver B'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Confirm proposed replacement'), findsOneWidget);
    expect(commits, 0);
    await tester.tap(find.text('Send Proposal'));
    await tester.pumpAndSettle();
    expect(commits, 1);
    expect(data['replacement_uid'], 'b');
    expect(data['responsible_uid'], 'a');
    expect(data['status'], 'awaiting_acceptance');
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 1100.0]) {
    testWidgets(
        'accepted replacement can start follow-up at width $width and enlarged text',
        (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = requestData();
      useClient(MockClient((_) async => http.Response(
          jsonEncode([
            {'document': document('follow_up_reassignments/current', data)}
          ]),
          200)));
      final auth = _Auth(user('b'));
      addTearDown(auth.dispose);
      var starts = 0;
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              home: Scaffold(
                  body: MediaQuery(
                      data: const MediaQueryData(
                          textScaler: TextScaler.linear(1.5)),
                      child: SingleChildScrollView(
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: FollowUpReassignmentActions(
                                  assignment: assignment,
                                  onStart: () => starts++))))))));
      await tester.pumpAndSettle();
      expect(find.textContaining('Temporary Assignment'), findsOneWidget);
      expect(find.textContaining('Original diver: Diver A'), findsOneWidget);
      await tester.tap(find.text('Start Follow-up Survey'));
      expect(starts, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'primary diver cannot start the month after replacement acceptance',
      (tester) async {
    useClient(MockClient((_) async => http.Response(
        jsonEncode([
          {
            'document':
                document('follow_up_reassignments/current', requestData())
          }
        ]),
        200)));
    final auth = _Auth(user('a'));
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            home: Scaffold(
                body: FollowUpReassignmentActions(
                    assignment: assignment,
                    onStart: () => fail('Unauthorized start'))))));
    await tester.pumpAndSettle();
    final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Start Follow-up Survey'));
    expect(button.onPressed, isNull);
    expect(find.text('Unavailable This Month'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
