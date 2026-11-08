import 'package:cots_monitor/features/admin/models/admin_record_table_row.dart';
import 'package:cots_monitor/features/expert/models/expert_action_item.dart';
import 'package:cots_monitor/features/expert/screens/expert_notifications_screen.dart';
import 'package:cots_monitor/models/area_handover.dart';
import 'package:cots_monitor/models/site_partner.dart';
import 'package:cots_monitor/services/site_partner_service.dart';
import 'package:cots_monitor/services/supabase_handover_service.dart';
import 'package:cots_monitor/models/follow_up_monitoring_model.dart';
import 'package:cots_monitor/widgets/follow_up_reassignment_controls.dart';
import 'package:cots_monitor/widgets/site_partner_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Stage 10: site partners (2 main Divers per site).

final _now = DateTime(2026, 11, 5, 15);

SitePartnerRequest _request(String id,
        {String candidate = 'Juan Dela Cruz',
        String source = 'invited',
        String status = 'waiting_expert',
        bool canDecide = true,
        bool canRespond = false,
        String area = 'Site 1 · Tambo',
        String code = 'S1',
        DateTime? queuedAt}) =>
    SitePartnerRequest.fromJson({
      'id': id,
      'area_code': code,
      'area_name': area,
      'candidate_uid': 'uid-$id',
      'candidate_name': candidate,
      'source': source,
      'invited_by_name': source == 'invited' ? 'Maria Santos' : null,
      'main_diver_name': 'Maria Santos',
      'status': status,
      'created_at': '2026-11-05T01:00:00Z',
      'queued_at': (queuedAt ?? DateTime.utc(2026, 11, 5, 6, 30)).toIso8601String(),
      'can_decide': canDecide,
      'can_respond': canRespond,
    });

class _FakePartners extends SitePartnerApi {
  _FakePartners({
    this.teamList = const [],
    this.requestList = const [],
    this.choiceList = const [],
  });
  List<SiteTeam> teamList;
  List<SitePartnerRequest> requestList;
  List<Map<String, dynamic>> choiceList;
  final calls = <String>[];

  @override
  Future<List<SiteTeam>> teams() async => teamList;
  @override
  Future<List<SitePartnerRequest>> requests() async => requestList;
  @override
  Future<List<Map<String, dynamic>>> choices(String areaCode) async =>
      choiceList;
  @override
  Future<void> invite(String areaCode, String diverUid) async =>
      calls.add('invite $areaCode $diverUid');
  @override
  Future<String> respond(String requestId, {required bool accept}) async {
    calls.add('respond $requestId $accept');
    requestList = const [];
    return accept ? 'waiting_expert' : 'declined';
  }

  @override
  Future<void> leave(String areaCode) async => calls.add('leave $areaCode');

  @override
  Future<String> decide(String requestId, {required bool approve}) async {
    calls.add('decide $requestId $approve');
    requestList = [
      for (final r in requestList)
        if (r.id != requestId) r
    ];
    return approve ? 'approved' : 'declined';
  }
}

class _NoHandovers extends AreaHandoverApi {
  @override
  Future<List<AreaHandover>> list() async => const [];
  @override
  Future<List<AreaMissedMonths>> missedMonths() async => const [];
}

Widget _app(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  test('a site shows both main Divers once there is a site partner', () {
    final team = SiteTeam.fromJson({
      'area_code': 'S1',
      'area_name': 'Site 1 · Tambo',
      'main_diver_uid': 'maria',
      'main_diver_name': 'Maria Santos',
      'partner_uid': 'juan',
      'partner_name': 'Juan Dela Cruz',
      'can_invite': false,
    });
    expect(team.mainDiversText, 'Maria Santos, Juan Dela Cruz (site partner)');
    expect(
        SiteTeam.fromJson({'main_diver_name': 'Maria Santos'}).mainDiversText,
        'Maria Santos');
  });

  test('requests explain where the candidate came from', () {
    expect(_request('a').reasonText, 'invited by Maria Santos, and accepted');
    expect(_request('b', source: 'recorded').reasonText,
        'recorded COTS at this site');
    expect(_request('c', status: 'closed').statusLabel,
        'Closed: the place was already filled');
  });

  test('candidates waiting for the Expert are listed, oldest first', () {
    final items = ExpertActions.build(sitePartners: [
      _request('pedro', candidate: 'Pedro Reyes', source: 'recorded'),
      _request('juan'),
      _request('done', status: 'approved', canDecide: false),
    ], now: _now);
    expect(items.map((i) => i.id), ['pedro', 'juan']);
    expect(items.first.kind, ExpertActionKind.sitePartner);
    expect(items.first.title, 'Site 1 · Tambo: approve a site partner?');
    expect(items.first.detail, startsWith('Pedro Reyes · recorded COTS at this site · '));
    expect(items.first.detail, endsWith('Main Diver: Maria Santos'));
    expect(items.first.decidedHere, isTrue);
  });

  testWidgets('the Expert approves a site partner right on the card',
      (tester) async {
    final partners = _FakePartners(requestList: [
      _request('pedro', candidate: 'Pedro Reyes', source: 'recorded'),
      _request('juan'),
    ]);
    final actions = ExpertActionsController(
      records: () => Stream.value(const <AdminRecordTableRow>[]),
      reassignments: () => Stream.value(const []),
      visits: () async => const [],
      handovers: _NoHandovers(),
      sitePartners: partners,
      clock: () => _now,
      refreshEvery: null,
    )..start();
    addTearDown(actions.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ExpertNotificationsScreen(actions: actions))));
    await tester.pumpAndSettle();
    expect(find.text('Site 1 · Tambo: approve a site partner?'),
        findsNWidgets(2));
    expect(find.text('Approve'), findsNWidgets(2));
    await tester.tap(find.text('Approve').last);
    await tester.pumpAndSettle();
    expect(find.text('Approve Juan Dela Cruz?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Approve').last);
    await tester.pumpAndSettle();
    expect(partners.calls, ['decide juan true']);
    expect(find.text('Juan Dela Cruz is now the site partner.'), findsOneWidget);
    expect(find.text('Site 1 · Tambo: approve a site partner?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Main Diver 1 sees both places and can add a site partner',
      (tester) async {
    final partners = _FakePartners(
      teamList: [
        SiteTeam.fromJson({
          'area_code': 'S1',
          'area_name': 'Site 1 · Tambo',
          'main_diver_uid': 'maria',
          'main_diver_name': 'Maria Santos',
          'can_invite': true,
        }),
      ],
      choiceList: [
        {'uid': 'juan', 'name': 'Juan Dela Cruz'},
        {'uid': 'pedro', 'name': 'Pedro Reyes'},
      ],
    );
    await tester.pumpWidget(
        _app(SiteTeamPanel(areaCode: 'S1', api: partners)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Maria Santos'), findsOneWidget);
    await tester.tap(find.text('Add site partner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Juan Dela Cruz'));
    await tester.pumpAndSettle();
    expect(find.text('Invite Juan Dela Cruz?'), findsOneWidget);
    expect(find.textContaining('cannot be removed later'), findsOneWidget);
    await tester.tap(find.text('Send invitation'));
    await tester.pumpAndSettle();
    expect(partners.calls, ['invite S1 juan']);
    expect(find.text('Invitation sent to Juan Dela Cruz.'), findsOneWidget);
  });

  testWidgets('no Add button once the site has a partner or an open invitation',
      (tester) async {
    final partners = _FakePartners(
      teamList: [
        SiteTeam.fromJson({
          'area_code': 'S1',
          'area_name': 'Site 1 · Tambo',
          'main_diver_name': 'Maria Santos',
          'can_invite': true,
        }),
      ],
      requestList: [
        _request('juan', status: 'invited', canDecide: false),
      ],
    );
    await tester.pumpWidget(
        _app(SiteTeamPanel(areaCode: 'S1', api: partners)));
    await tester.pumpAndSettle();
    expect(find.text('Add site partner'), findsNothing);
    expect(
        find.text(
            'Site partner: Juan Dela Cruz · Waiting for Juan Dela Cruz to accept'),
        findsOneWidget);
  });

  testWidgets('the invited Diver accepts before the Expert decides',
      (tester) async {
    final partners = _FakePartners(requestList: [
      _request('juan', status: 'invited', canDecide: false, canRespond: true),
    ]);
    await tester.pumpWidget(_app(SitePartnerInvitesCard(api: partners)));
    await tester.pumpAndSettle();
    expect(find.text('Site partner invitation'), findsOneWidget);
    expect(
        find.text(
            'Maria Santos invited you to be the site partner of Site 1 · Tambo.'),
        findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Accept').last);
    await tester.pumpAndSettle();
    expect(partners.calls, ['respond juan true']);
    expect(find.text('Accepted. The Expert will now approve or decline.'),
        findsOneWidget);
    expect(find.text('Site partner invitation'), findsNothing);
  });

  // Stage 11: shared monthly visits.
  test('either main Diver records the visit unless a replacement covers it',
      () {
    const main = {'maria', 'juan'};
    expect(
        followUpMayRecord(
            responsibleUid: 'maria', mainDiverUids: main, userUid: 'juan'),
        isTrue);
    expect(
        followUpMayRecord(
            responsibleUid: 'maria', mainDiverUids: main, userUid: 'maria'),
        isTrue);
    expect(
        followUpMayRecord(
            responsibleUid: 'maria', mainDiverUids: main, userUid: 'pedro'),
        isFalse);
    // An accepted replacement covers the month alone.
    expect(
        followUpMayRecord(
            responsibleUid: 'pedro', mainDiverUids: main, userUid: 'juan'),
        isFalse);
    expect(
        followUpMayRecord(
            responsibleUid: 'pedro', mainDiverUids: main, userUid: 'pedro'),
        isTrue);
  });

  test('a site carries its site partner from the database', () {
    final assignment = FollowUpAssignmentModel.fromMap({
      'area_id': 'S1',
      'primary_diver_uid': 'maria',
      'primary_diver_name': 'Maria Santos',
      'partner_uid': 'juan',
      'partner_name': 'Juan Dela Cruz',
      'initial_date': '2026-09-01T02:00:00Z',
    }, areaId: 'S1');
    expect(assignment.mainDiverUids, {'maria', 'juan'});
    expect(assignment.partnerName, 'Juan Dela Cruz');
    final alone = FollowUpAssignmentModel.fromMap(
        {'area_id': 'S2', 'primary_diver_uid': 'maria'},
        areaId: 'S2');
    expect(alone.mainDiverUids, {'maria'});
  });

  testWidgets('the site partner can leave the site', (tester) async {
    final partners = _FakePartners(teamList: [
      SiteTeam.fromJson({
        'area_code': 'S1',
        'area_name': 'Site 1 · Tambo',
        'main_diver_name': 'Maria Santos',
        'partner_uid': 'juan',
        'partner_name': 'Juan Dela Cruz',
        'can_leave': true,
      }),
    ]);
    await tester.pumpWidget(
        _app(SiteTeamPanel(areaCode: 'S1', api: partners)));
    await tester.pumpAndSettle();
    expect(find.text('Add site partner'), findsNothing);
    await tester.tap(find.text('Leave site'));
    await tester.pumpAndSettle();
    expect(find.text('Leave Site 1 · Tambo?'), findsOneWidget);
    expect(find.textContaining('past records and visits stay'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Leave site'));
    await tester.pumpAndSettle();
    expect(partners.calls, ['leave S1']);
    expect(find.text('You left Site 1 · Tambo.'), findsOneWidget);
  });
}
