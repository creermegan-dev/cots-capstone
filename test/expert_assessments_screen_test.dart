import 'package:cots_monitor/features/expert/screens/expert_assessments_screen.dart';
import 'package:cots_monitor/models/follow_up_monitoring_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FollowUpSurveyModel visit() => FollowUpSurveyModel.fromMap({
      'area_name': 'Zone C · C-01',
      'barangay': 'Test Barangay',
      'submitted_by': 'Diver A',
      'survey_calendar_date': '2026-10-05',
      'field_observed_count': 12,
      'field_eliminated_count': 12,
      'confirmed_count': 12,
      'waiting_count': 0,
      'surveyed_area_square_meters': 2500,
      'density_per_ha': 48.0,
      'calculated_level': 'Moderate',
      'status': 'completed',
    }, id: 'visit-1');

void main() {
  testWidgets('the Expert confirms the calculated level', (tester) async {
    var loads = 0;
    final saved = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ExpertAssessmentsScreen(
      loadVisits: () async => loads++ == 0 ? [visit()] : [],
      confirm: ({required surveyId, required level, reason = ''}) async =>
          saved.add('$surveyId:$level:$reason'),
    ))));
    await tester.pumpAndSettle();
    expect(find.textContaining('48.00 COTS/ha · Moderate'), findsOneWidget);
    expect(find.textContaining('COTS found and removed: 12 (12 confirmed)'),
        findsOneWidget);
    expect(find.textContaining('Field-observed'), findsNothing);
    expect(find.text('Calculated level: Moderate · potential outbreak'),
        findsOneWidget);
    await tester.tap(find.text('Confirm Moderate'));
    await tester.pumpAndSettle();
    expect(saved, ['visit-1:Moderate:']);
    expect(find.text('No completed visits are waiting for an assessment.'),
        findsOneWidget);
  });

  testWidgets('a different level needs a reason', (tester) async {
    final saved = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ExpertAssessmentsScreen(
      loadVisits: () async => [visit()],
      confirm: ({required surveyId, required level, reason = ''}) async =>
          saved.add('$level:$reason'),
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose another level'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High · confirmed outbreak'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save level'));
    await tester.pumpAndSettle();
    expect(find.text('Give a reason when the level differs from the calculated level.'),
        findsOneWidget);
    expect(saved, isEmpty);
    await tester.enterText(find.byType(TextField), 'Dense cluster');
    await tester.tap(find.text('Save level'));
    await tester.pumpAndSettle();
    expect(saved, ['High:Dense cluster']);
  });

  testWidgets('a failed load can be retried', (tester) async {
    var loads = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ExpertAssessmentsScreen(loadVisits: () async {
      if (loads++ == 0) throw StateError('offline');
      return [visit()];
    }))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm Moderate'), findsOneWidget);
  });
}
