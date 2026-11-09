import 'dart:async';

import 'package:cots_monitor/features/admin/models/admin_record_table_row.dart';
import 'package:cots_monitor/features/expert/models/expert_action_item.dart';
import 'package:cots_monitor/features/expert/screens/expert_notifications_screen.dart';
import 'package:cots_monitor/features/expert/screens/expert_shell_screen.dart';
import 'package:cots_monitor/models/app_notification.dart';
import 'package:cots_monitor/models/area_handover.dart';
import 'package:cots_monitor/models/follow_up_monitoring_model.dart';
import 'package:cots_monitor/models/follow_up_reassignment.dart';
import 'package:cots_monitor/services/supabase_handover_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Expert Notifications tab (claude/agreed_workflow_decisions.md):
/// "Needs your action" and "All notices".

// Oct 31, 2026, 10:00 in Manila.
final _now = DateTime.utc(2026, 10, 31, 2);

AdminRecordTableRow _row(
  String id, {
  int confidence = 95,
  String zoneAssignedTo = '',
  bool confirmed = false,
}) =>
    AdminRecordTableRow(1, id, 'Reef A', 'Oct 30, 2026', 2, null, 'Low',
        'Diver Bravo', confidence,
        documentId: 'doc-$id',
        adminConfirmed: confirmed,
        zoneAssignedTo: zoneAssignedTo);

FollowUpSurveyModel _visit() => FollowUpSurveyModel.fromMap({
      'area_name': 'Zone C · C-01',
      'barangay': 'Test Barangay',
      'submitted_by': 'Diver A',
      'survey_calendar_date': '2026-10-05',
      'field_observed_count': 12,
      'field_eliminated_count': 12,
      'status': 'completed',
    }, id: 'visit-1');

FollowUpReassignment _request(String id, String status, {int month = 10}) =>
    FollowUpReassignment(id, {
      'area_id': 'REEF-1',
      'area_name': 'Zone B · B-02',
      'primary_uid': 'diver-a',
      'primary_name': 'Diver Alpha',
      'status': status,
      'year': 2026,
      'month': month,
      'revision': 1,
    });

AreaHandover _handover(String id,
        {bool canOffer = true, String? offerStatus, String? toDiverName}) =>
    AreaHandover.fromJson({
      'id': id,
      'area_code': 'REEF-2',
      'area_name': 'Stage Four Reef',
      'from_diver_uid': 'diver-a',
      'from_diver_name': 'Diver Alpha',
      'started_reason': 'diver_request',
      'reason': 'Moving to another city',
      'status': 'requested',
      'offer_status': offerStatus,
      'to_diver_name': toDiverName,
      'can_offer': canOffer,
    });

AreaMissedMonths _missed(String code, int months, {bool open = false}) =>
    AreaMissedMonths.fromJson({
      'area_code': code,
      'area_name': 'Area $code',
      'main_diver_name': 'Diver Alpha',
      'missed_months': months,
      'open_handover': open,
    });

class _FakeHandovers extends AreaHandoverApi {
  _FakeHandovers({this.missed = const []});
  List<AreaHandover> handovers = const [];
  List<AreaMissedMonths> missed;
  @override
  Future<List<AreaHandover>> list() async => handovers;
  @override
  Future<List<AreaMissedMonths>> missedMonths() async => missed;
}

ExpertActionsController _controller({
  List<AdminRecordTableRow> records = const [],
  List<FollowUpSurveyModel> Function()? visits,
  List<FollowUpReassignment> reassignments = const [],
  _FakeHandovers? handovers,
}) =>
    ExpertActionsController(
      supabase: false,
      records: () => Stream.value(records),
      reassignments: () => Stream.value(reassignments),
      visits: () async => (visits ?? () => const <FollowUpSurveyModel>[])(),
      handovers: handovers ?? _FakeHandovers(),
      clock: () => _now,
      refreshEvery: null,
    );

AppNotification _notice(String type, String title) => AppNotification(
      id: 'n-$type',
      recipientUid: 'expert',
      type: type,
      title: title,
      body: 'Body of $title',
      relatedRecordId: 'CAP-9',
      zone: 'Reef A',
      dueAt: null,
      createdAt: DateTime(2026, 10, 31, 9),
      isRead: false,
    );

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  test('the fixtures have the statuses the Verification tab shows', () {
    expect(_row('CAP-1', confidence: 60).displayStatus, 'Needs Review');
    expect(_row('CAP-3').displayStatus, 'Verified');
    expect(_row('CAP-2', zoneAssignedTo: 'Diver Alpha').displayStatus,
        'Needs Review');
    expect(
        _row('CAP-4', zoneAssignedTo: 'Diver Alpha', confirmed: true)
            .displayStatus,
        'Verified');
  });

  test('every agreed kind of Expert work is listed, in the agreed order', () {
    final items = ExpertActions.build(
      records: [
        _row('CAP-2', zoneAssignedTo: 'Diver Alpha'),
        _row('CAP-1', confidence: 60),
        _row('CAP-3'),
        _row('CAP-4', zoneAssignedTo: 'Diver Alpha', confirmed: true),
      ],
      visits: [_visit()],
      reassignments: [
        _request('r-1', 'requested'),
        _request('r-2', 'replacement_needed'),
        _request('r-3', 'awaiting_acceptance'),
        _request('r-4', 'accepted'),
        _request('r-5', 'requested', month: 9),
      ],
      handovers: [
        _handover('h-1', offerStatus: 'declined', toDiverName: 'Diver Bravo'),
        _handover('h-2', canOffer: false),
      ],
      missedMonths: [
        _missed('A-5', 5),
        _missed('A-6', 6, open: true),
        _missed('A-4', 4),
      ],
      now: _now,
    );

    expect([
      for (final item in items) item.kind
    ], [
      ExpertActionKind.recordReview,
      ExpertActionKind.zoneApproval,
      ExpertActionKind.reassignment,
      ExpertActionKind.reassignment,
      ExpertActionKind.handover,
      ExpertActionKind.missedMonths,
    ]);
    expect([for (final item in items) item.id],
        ['doc-CAP-1', 'doc-CAP-2', 'r-1', 'r-2', 'h-1', 'A-5']);
    expect([
      for (final item in items) item.title
    ], [
      'Detection needs review',
      'Record needs your approval',
      'Reassignment request: choose a replacement Diver',
      'Replacement declined: choose another Diver',
      'Handover offer declined: choose another Diver',
      '5 missed months in a row',
    ]);
    expect([
      for (final item in items) item.place
    ], [
      ExpertActionPlace.verification,
      ExpertActionPlace.verification,
      ExpertActionPlace.reassignments,
      ExpertActionPlace.reassignments,
      ExpertActionPlace.reassignments,
      ExpertActionPlace.reassignments,
    ]);
    expect(items[1].detail,
        'Another Diver in an assigned area · CAP-2 · Reef A · by Diver Bravo · area assigned to Diver Alpha');
    expect(items[2].detail,
        'Zone B · B-02 · October 2026 · main Diver: Diver Alpha');
    expect(items[4].detail,
        'Stage Four Reef · requested by Diver Alpha · Moving to another city');
    expect(items[5].detail,
        'Area A-5 · main Diver: Diver Alpha · You can start an area handover.');
  });

  test('a handover that was not declined asks for a new Diver', () {
    final items = ExpertActions.build(handovers: [_handover('h-1')], now: _now);
    expect(items.single.title, 'Area handover: choose a new Diver');
  });

  test('handled work leaves the list', () {
    final waiting = ExpertActions.build(
        records: [_row('CAP-1', confidence: 60)],
        reassignments: [_request('r-1', 'requested')],
        now: _now);
    expect(waiting, hasLength(2));
    final handled = ExpertActions.build(
        records: [_row('CAP-1', confidence: 60, confirmed: true)],
        reassignments: [_request('r-1', 'awaiting_acceptance')],
        now: _now);
    expect(handled, isEmpty);
  });

  test('the controller counts items once every source has answered', () async {
    final records = StreamController<List<AdminRecordTableRow>>();
    final actions = ExpertActionsController(
      supabase: false,
      records: () => records.stream,
      reassignments: () => Stream.value([_request('r-1', 'requested')]),
      visits: () async => [_visit()],
      handovers: _FakeHandovers(missed: [_missed('A-5', 5)]),
      clock: () => _now,
      refreshEvery: null,
    )..start();
    await pumpEventQueue();
    expect(actions.loaded, isFalse);
    expect(actions.count, 0);
    records.add([_row('CAP-1', confidence: 60)]);
    await pumpEventQueue();
    expect(actions.loaded, isTrue);
    // Record, reassignment and missed months (visits no longer wait).
    expect(actions.count, 3);
    records.add(const []);
    await pumpEventQueue();
    expect(actions.count, 2);
    actions.dispose();
    await records.close();
  });

  test('a source that fails is reported and the rest still show', () async {
    final actions = ExpertActionsController(
      supabase: false,
      records: () => Stream.value([_row('CAP-1', confidence: 60)]),
      reassignments: () => Stream.value(const []),
      visits: () async => throw StateError('offline'),
      handovers: _FakeHandovers(),
      clock: () => _now,
      refreshEvery: null,
    )..start();
    await pumpEventQueue();
    expect(actions.loaded, isTrue);
    expect(actions.count, 1);
    expect(
        actions.errors.single, startsWith('Could not check monthly visits:'));
    actions.dispose();
  });

  testWidgets('Needs your action lists items and opens the right tab',
      (tester) async {
    final actions = _controller(
      records: [_row('CAP-2', zoneAssignedTo: 'Diver Alpha')],
      visits: () => [_visit()],
    )..start();
    final opened = <ExpertActionPlace>[];
    await tester.pumpWidget(
        _app(ExpertNotificationsScreen(actions: actions, onOpen: opened.add)));
    await tester.pumpAndSettle();

    expect(find.text('Needs your action (1)'), findsOneWidget);
    expect(find.text('Record needs your approval'), findsOneWidget);
    expect(find.text('Open Verification'), findsOneWidget);
    // 2026-11-08: monthly visits no longer wait for an assessment.
    expect(find.text('Monthly visit waiting for assessment'), findsNothing);
    await tester.tap(find.text('Record needs your approval'));
    expect(opened, [ExpertActionPlace.verification]);
    actions.dispose();
  });

  testWidgets('nothing waiting says so', (tester) async {
    final actions = _controller()..start();
    await tester.pumpWidget(_app(ExpertNotificationsScreen(actions: actions)));
    await tester.pumpAndSettle();
    expect(find.text('Needs your action (0)'), findsOneWidget);
    expect(find.text(ExpertNotificationsScreen.nothingWaiting), findsOneWidget);
    actions.dispose();
  });

  testWidgets('All notices shows record notices, including Stage 2 reminders',
      (tester) async {
    final actions = _controller()..start();
    await tester.pumpWidget(_app(ExpertNotificationsScreen(
      actions: actions,
      noticesStream: Stream.value([
        _notice(AppNotification.zoneReviewReminder,
            'Reminder: record needs your approval'),
        _notice(AppNotification.reviewNeeded, 'Detection needs review'),
        _notice('handover_requested', 'Area handover requested'),
      ]),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All notices'));
    await tester.pumpAndSettle();

    expect(find.text('Reminder: record needs your approval'), findsOneWidget);
    expect(find.text('Detection needs review'), findsOneWidget);
    expect(find.text('Area handover requested'), findsOneWidget);
    expect(find.text('3 unread'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);
    // The administrator page title is not repeated inside the tab.
    expect(
        find.text('Real system activities, assignments, and review updates.'),
        findsNothing);
    actions.dispose();
  });

  test('Expert dashboard is first and action items open the right tab', () {
    expect(ExpertShellScreen.tabLabels, [
      'Dashboard',
      'Verification',
      'Personnel Verification',
      'Site Coverage',
      'Assessments',
      'Map Monitoring',
      'Notifications',
    ]);
    expect(ExpertShellScreen.tabFor(ExpertActionPlace.verification), 1);
    expect(ExpertShellScreen.tabFor(ExpertActionPlace.reassignments), 3);
    expect(ExpertShellScreen.tabFor(ExpertActionPlace.assessments), 4);
  });

  testWidgets('the tab shows how many items need action', (tester) async {
    final actions = _controller(
      records: [_row('CAP-1', confidence: 60)],
      reassignments: [_request('r-1', 'requested')],
    )..start();
    await tester.pumpWidget(
        _app(Center(child: ExpertNotificationsTabLabel(actions: actions))));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    actions.dispose();
  });

  testWidgets('no number when nothing needs action', (tester) async {
    final actions = _controller()..start();
    await tester.pumpWidget(
        _app(Center(child: ExpertNotificationsTabLabel(actions: actions))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('expert-action-count')), findsNothing);
    actions.dispose();
  });
}
