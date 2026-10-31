import 'package:cots_monitor/features/expert/models/expert_action_item.dart';
import 'package:cots_monitor/features/expert/screens/expert_assessments_screen.dart';
import 'package:cots_monitor/models/activity_type.dart';
import 'package:cots_monitor/models/cots_tally.dart';
import 'package:cots_monitor/models/follow_up_monitoring_model.dart';
import 'package:cots_monitor/widgets/early_visit_flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stage 5 (claude/agreed_workflow_decisions.md): after an injection removal.
/// The database decides the flag and excused months; the app shows the flag.

const _flag =
    'Visit within 2 days of an injection on Nov 3, 9:40 AM: injected COTS may still be alive.';

FollowUpSurveyModel _visit({String? note, String id = 'visit-1'}) =>
    FollowUpSurveyModel.fromMap({
      'area_name': 'Zone C · C-01',
      'barangay': 'Test Barangay',
      'submitted_by': 'Diver A',
      'survey_calendar_date': '2026-11-04',
      'field_observed_count': 0,
      'field_eliminated_count': 0,
      'confirmed_count': 0,
      'waiting_count': 0,
      'surveyed_area_square_meters': 2500,
      'density_per_ha': 0.0,
      'calculated_level': 'Low',
      'status': 'completed',
      if (note != null) 'early_visit_note': note,
    }, id: id);

void main() {
  test('Divers choose from manual removal, vinegar and ox bile only', () {
    expect(RemovalMethod.options,
        [RemovalMethod.manual, RemovalMethod.vinegar, RemovalMethod.oxBile]);
    expect(RemovalMethod.options, isNot(contains(RemovalMethod.communityCleanup)));
    expect(RemovalMethod.options, isNot(contains(RemovalMethod.researchCollection)));
  });

  test('old records keep their method and still count under "Other"', () {
    final grouped = RemovalMethodCount.group([
      const RemovalMethodCount(
          method: RemovalMethod.communityCleanup, cots: 4, removals: 1),
      const RemovalMethodCount(
          method: RemovalMethod.researchCollection, cots: 2, removals: 1),
    ]);
    expect(grouped.single.method, RemovalMethodCount.otherLabel);
    expect(grouped.single.cots, 6);
  });

  test('the visit carries the database flag; blank or missing means none', () {
    expect(_visit(note: _flag).earlyVisitNote, _flag);
    expect(_visit(note: '  ').earlyVisitNote, isNull);
    expect(_visit().earlyVisitNote, isNull);
  });

  testWidgets('the Expert sees the flag on the Assessments tab', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ExpertAssessmentsScreen(
      loadVisits: () async =>
          [_visit(note: _flag), _visit(id: 'visit-2')],
      confirm: ({required surveyId, required level, reason = ''}) async {},
    ))));
    await tester.pumpAndSettle();
    expect(find.text(_flag), findsOneWidget);
    expect(find.byType(EarlyVisitFlag), findsOneWidget);
  });

  test('"Needs your action" shows the flag with the visit', () {
    final items = ExpertActions.build(
        visits: [_visit(note: _flag), _visit(id: 'visit-2')],
        now: DateTime.utc(2026, 11, 4));
    expect(items[0].detail,
        'Zone C · C-01 · Test Barangay · Nov 4, 2026 · by Diver A\n$_flag');
    expect(items[1].detail,
        'Zone C · C-01 · Test Barangay · Nov 4, 2026 · by Diver A');
  });

  testWidgets('visit details show the flag', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: EarlyVisitFlag(note: _flag))));
    expect(find.text(_flag), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });
}
