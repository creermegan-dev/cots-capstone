import 'dart:io';

import 'package:cots_monitor/models/area_handover.dart';
import 'package:cots_monitor/models/follow_up_monitoring_model.dart';
import 'package:cots_monitor/services/supabase_handover_service.dart';
import 'package:cots_monitor/widgets/area_handover_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stage 4 (claude/agreed_workflow_decisions.md): hand over this area.
class _FakeApi extends AreaHandoverApi {
  _FakeApi({this.handovers = const [], this.missed = const []});

  List<AreaHandover> handovers;
  List<AreaMissedMonths> missed;
  final calls = <String>[];

  @override
  Future<List<AreaHandover>> list() async => handovers;
  @override
  Future<List<AreaMissedMonths>> missedMonths() async => missed;
  @override
  Future<void> request(String areaCode, String reason, String note) async =>
      calls.add('request $areaCode | $reason | $note');
  @override
  Future<void> start(String areaCode) async => calls.add('start $areaCode');
  @override
  Future<void> offer(String handoverId, String diverUid) async =>
      calls.add('offer $handoverId $diverUid');
  @override
  Future<String> respond(String offerId, {required bool accept}) async {
    calls.add('respond $offerId $accept');
    return accept ? 'accepted' : 'declined';
  }

  @override
  Future<void> cancel(String handoverId) async =>
      calls.add('cancel $handoverId');
  @override
  Future<List<Map<String, dynamic>>> directory() async => [
        {'uid': 'diver-a', 'name': 'Diver Alpha', 'eligible': true},
        {'uid': 'diver-b', 'name': 'Diver Bravo', 'eligible': true},
      ];
}

const _note =
    'This month hasn\'t been monitored yet. You can do this month\'s visit any day.';

AreaHandover _handover({
  String status = 'requested',
  bool canRespond = false,
  bool canCancel = false,
  bool canOffer = false,
  String? offerStatus,
  String? toDiverName,
}) =>
    AreaHandover.fromJson({
      'id': 'h-1',
      'area_code': 'REEF-1',
      'area_name': 'Stage Four Reef',
      'from_diver_uid': 'diver-a',
      'from_diver_name': 'Diver Alpha',
      'started_reason': 'diver_request',
      'reason': 'Moving to another city',
      'note': 'Reef access is from the pier',
      'status': status,
      'offer_id': status == 'offered' ? 'o-1' : null,
      'offer_status': offerStatus,
      'to_diver_name': toDiverName,
      'month_note': status == 'offered' ? _note : null,
      'can_respond': canRespond,
      'can_cancel': canCancel,
      'can_offer': canOffer,
    });

FollowUpAssignmentModel _assignment() => FollowUpAssignmentModel(
      areaId: 'REEF-1',
      areaName: 'Stage Four Reef',
      barangay: 'Test',
      municipality: 'Test',
      primaryDiverUid: 'diver-a',
      primaryDiverName: 'Diver Alpha',
      initialCaptureId: 'cap-1',
      initialDate: DateTime(2026, 7, 14),
      initialDetectedCount: 3,
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child))));
  await tester.pumpAndSettle();
}

void main() {
  test('status wording follows the handover', () {
    expect(_handover().statusLabel,
        'Waiting for the Expert to choose a new Diver.');
    expect(
        _handover(status: 'offered', toDiverName: 'Diver Bravo').statusLabel,
        'Offered to Diver Bravo. Waiting for their answer.');
    expect(
        _handover(offerStatus: 'declined', toDiverName: 'Diver Charlie')
            .statusLabel,
        'Diver Charlie declined. The Expert will choose another Diver.');
    expect(_handover(status: 'accepted', toDiverName: 'Diver Bravo').isOpen,
        isFalse);
  });

  test('the Expert can start a handover after 5 missed months in a row', () {
    AreaMissedMonths area(int missed, {bool open = false}) =>
        AreaMissedMonths.fromJson({
          'area_code': 'A',
          'area_name': 'A',
          'main_diver_name': 'Diver Alpha',
          'missed_months': missed,
          'open_handover': open,
        });
    expect(AreaMissedMonths.monthsBeforeHandover, 5);
    expect(area(4).canStartHandover, isFalse);
    expect(area(5).canStartHandover, isTrue);
    expect(area(7, open: true).canStartHandover, isFalse);
  });

  testWidgets('the main Diver asks with a required reason and optional note',
      (tester) async {
    final api = _FakeApi();
    await _pump(tester, AreaHandoverButton(assignment: _assignment(), api: api));
    await tester.tap(find.text('Hand over this area'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    expect(find.text('Give a reason for the handover.'), findsOneWidget);
    expect(api.calls, isEmpty);
    await tester.enterText(
        find.byKey(const ValueKey('handover-reason')), 'Moving away');
    await tester.enterText(
        find.byKey(const ValueKey('handover-note')), 'Use the pier');
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    expect(api.calls, ['request REEF-1 | Moving away | Use the pier']);
  });

  testWidgets('an open request shows its status and can be cancelled',
      (tester) async {
    final api = _FakeApi(handovers: [_handover(canCancel: true)]);
    await _pump(tester, AreaHandoverButton(assignment: _assignment(), api: api));
    expect(find.text('Hand over this area'), findsNothing);
    expect(find.text('Waiting for the Expert to choose a new Diver.'),
        findsOneWidget);
    await tester.tap(find.text('Cancel handover'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel handover'));
    await tester.pumpAndSettle();
    expect(api.calls, ['cancel h-1']);
  });

  testWidgets('the new Diver sees the reason, note and month note, and accepts',
      (tester) async {
    final api = _FakeApi(handovers: [
      _handover(status: 'offered', canRespond: true, toDiverName: 'Diver Bravo')
    ]);
    await _pump(tester, HandoverOffersCard(api: api));
    expect(find.text('Diver Alpha is handing over Stage Four Reef.'),
        findsOneWidget);
    expect(find.text(_note), findsOneWidget);
    expect(find.textContaining('Reef access is from the pier'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Accept')));
    await tester.pumpAndSettle();
    expect(api.calls, ['respond o-1 true']);
  });

  testWidgets('the Expert chooses a Diver and starts handovers at 5 months',
      (tester) async {
    final api = _FakeApi(handovers: [
      _handover(canOffer: true)
    ], missed: [
      AreaMissedMonths.fromJson({
        'area_code': 'QUIET',
        'area_name': 'Quiet Reef',
        'main_diver_name': 'Diver Delta',
        'missed_months': 6,
        'open_handover': false,
      }),
      AreaMissedMonths.fromJson({
        'area_code': 'BUSY',
        'area_name': 'Busy Reef',
        'main_diver_name': 'Diver Echo',
        'missed_months': 4,
        'open_handover': false,
      }),
    ]);
    await _pump(tester, ExpertHandoversSection(api: api));
    expect(find.text('Quiet Reef'), findsOneWidget);
    expect(find.text('Busy Reef'), findsNothing);
    await tester.tap(find.text('Choose a Diver'));
    await tester.pumpAndSettle();
    expect(find.text('Diver Alpha'), findsNothing,
        reason: 'The Diver handing over is not offered the area');
    await tester.tap(find.text('Diver Bravo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send offer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start handover'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start handover'));
    await tester.pumpAndSettle();
    expect(api.calls, ['offer h-1 diver-b', 'start QUIET']);
  });

  test('the database update keeps the agreed month notes', () {
    final sql = File('supabase/migrations/20261031000400_area_handover.sql')
        .readAsStringSync();
    expect(sql,
        contains('This month has already been monitored. Your first visit is next month.'));
    expect(sql,
        contains('Another Diver is covering this month. Your first visit is next month.'));
    expect(sql, contains("You can do this month''s visit any day."));
    expect(sql, contains('function cots_private.main_diver(aid uuid)'));
  });
}
