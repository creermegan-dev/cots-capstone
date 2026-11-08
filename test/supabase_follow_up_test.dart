import 'package:cots_monitor/models/davao_gulf_geography.dart';
import 'package:cots_monitor/models/follow_up_monitoring_model.dart';
import 'package:cots_monitor/services/supabase_follow_up_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/map_test_data.dart';

void main() {
  loadTestMap();
  final area = DavaoGulfGeography.allBarangays.first;

  test('new visit IDs are version-4 UUIDs', () {
    final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    for (var i = 0; i < 20; i++) {
      expect(SupabaseFollowUpService.newId(), matches(pattern));
    }
    expect(SupabaseFollowUpService.newId(), isNot(SupabaseFollowUpService.newId()));
  });

  test('visit dates are sent as calendar dates', () {
    expect(SupabaseFollowUpService.dateOnly(DateTime(2026, 3, 7, 23, 59)),
        '2026-03-07');
  });

  test('assignment rows keep the names the Firebase version showed', () {
    final assignment = SupabaseFollowUpService.assignmentFromRow({
      'area_id': area.id,
      'area_label': 'ignored',
      'primary_diver_uid': 'diver-a',
      'primary_diver_name': 'Diver A',
      'initial_capture_id': 'capture-1',
      'initial_date': '2026-09-01T02:00:00Z',
      'initial_detected_count': 3,
    });
    expect(assignment.areaId, area.id);
    expect(assignment.areaName, area.displayName);
    expect(assignment.barangay, area.name);
    expect(assignment.primaryDiverUid, 'diver-a');
    expect(assignment.primaryDiverName, 'Diver A');
    expect(assignment.initialDetectedCount, 3);
    expect(assignment.initialDate.toUtc(), DateTime.utc(2026, 9, 1, 2));
  });

  test('unknown area codes fall back to the database name', () {
    final assignment = SupabaseFollowUpService.assignmentFromRow({
      'area_id': 'TEST-AREA',
      'area_label': 'Test Reef',
      'barangay': 'Test Barangay',
      'municipality': 'Samal',
    });
    expect(assignment.areaName, 'Test Reef');
    expect(assignment.barangay, 'Test Barangay');
    expect(assignment.municipality, 'Samal');
  });

  Map<String, dynamic> surveyRow(String status) => {
        'id': 'visit-1',
        'area_id': area.id,
        'uid': 'diver-a',
        'submitted_by': 'Diver A',
        'survey_calendar_date': '2026-10-05',
        'field_observed_count': 4,
        'field_eliminated_count': 2,
        'capture_ids': ['c1', 'c2'],
        'ai_detected_count': 3,
        'submitted_at': '2026-10-05T03:00:00Z',
        'gps': {'latitude': 7.1, 'longitude': 125.7},
        'surveyed_area_square_meters': 25,
        'elimination_method': 'Injection',
        'notes': 'Calm',
        'status': status,
      };

  test('visit rows carry the visit details and the database status', () {
    final survey = SupabaseFollowUpService.surveyFromRow(surveyRow('pending'));
    expect(survey.id, 'visit-1');
    expect(survey.surveyDate, DateTime(2026, 10, 5));
    expect(survey.fieldObservedCount, 4);
    expect(survey.fieldEliminatedCount, 2);
    expect(survey.captureIds, ['c1', 'c2']);
    expect(survey.aiDetectedCount, 3);
    expect(survey.latitude, 7.1);
    expect(survey.surveyedAreaSquareMeters, 25);
    expect(survey.serverStatus, 'pending');
  });

  test('a visit shows one found-and-removed value with the confirmed part',
      () {
    FollowUpSurveyModel visitWith(Map<String, Object> counts) =>
        SupabaseFollowUpService.surveyFromRow(
            {...surveyRow('pending'), ...counts});
    expect(
        followUpCountSummary(visitWith({
          'field_observed_count': 4,
          'field_eliminated_count': 4,
          'confirmed_count': 3,
          'waiting_count': 1,
        })),
        'COTS found and removed: 4 (3 confirmed, 1 waiting for Expert)');
    // The Expert rejected one COTS: it no longer counts as confirmed.
    expect(
        followUpCountSummary(visitWith({
          'field_observed_count': 4,
          'field_eliminated_count': 4,
          'confirmed_count': 3,
          'waiting_count': 0,
        })),
        'COTS found and removed: 4 (3 confirmed)');
    expect(
        followUpCountSummary(visitWith({
          'field_observed_count': 0,
          'field_eliminated_count': 0,
          'confirmed_count': 0,
          'waiting_count': 0,
        })),
        'COTS found and removed: 0');
    // Firebase rows have no confirmed count and keep their two values.
    expect(followUpCountSummary(visitWith({})), 'COTS found: 4, removed: 2');
    expect(followUpCountValue(visitWith({})), '4 found, 2 removed');
    // The details screen shows the value under its own label.
    expect(
        followUpCountValue(visitWith({
          'field_observed_count': 5,
          'field_eliminated_count': 5,
          'confirmed_count': 5,
          'waiting_count': 0,
        })),
        '5 (5 confirmed)');
  });

  test('completion comes from the database status', () {
    FollowUpSurveyStatus statusOf(String status) => followUpSurveyStatus(
        SupabaseFollowUpService.surveyFromRow(surveyRow(status)), const []);
    expect(statusOf('completed'), FollowUpSurveyStatus.completed);
    expect(statusOf('pending'), FollowUpSurveyStatus.pendingValidation);
    expect(statusOf('pending_late_review'),
        FollowUpSurveyStatus.pendingValidation);
    expect(statusOf('historical_only'), FollowUpSurveyStatus.needsCorrection);
  });

  test('replacement requests match what the screens expect', () {
    final request = SupabaseFollowUpService.reassignmentFromRow({
      'id': 'req-1',
      'area_id': area.id,
      'primary_uid': 'diver-a',
      'primary_name': 'Diver A',
      'year': 2026,
      'month': 10,
      'responsible_uid': 'diver-a',
      'requester_uid': 'diver-a',
      'reason': 'Sick',
      'status': 'awaiting_acceptance',
      'revision': 2,
      'requested_at': '2026-10-02T01:00:00Z',
      'proposal_id': 'prop-1',
      'replacement_uid': 'diver-b',
      'replacement_name': 'Diver B',
    });
    expect(request.id, 'req-1');
    expect(request.areaId, area.id);
    expect(request.month, DateTime(2026, 10));
    expect(request.revision, 2);
    expect(request.replacementUid, 'diver-b');
    expect(request.statusLabel, 'Awaiting Acceptance');
    expect(request.data['requested_at'], isA<DateTime>());
    expect(request.data['area_name'], area.displayName);
    expect(request.data['proposal_id'], 'prop-1');
    expect(request.data['participants'],
        containsAll(<String>['diver-a', 'diver-b']));
    expect(request.isCurrent(DateTime.utc(2026, 10, 15)), isTrue);
    expect(request.isCurrent(DateTime.utc(2026, 11, 15)), isFalse);
  });

  test('history uses the labels the history list already shows', () {
    final history = SupabaseFollowUpService.historyFromRows([
      {'revision': 1, 'action': 'reassignment_requested', 'actor_uid': 'Diver A',
        'at': '2026-10-02T01:00:00Z'},
      {'revision': 2, 'action': 'replacement_proposed', 'actor_uid': 'Expert',
        'at': '2026-10-02T02:00:00Z', 'replacement_name': 'Diver B'},
      {'revision': 3, 'action': 'reassignment_closed', 'cancelled': false,
        'actor_uid': 'Expert', 'at': '2026-10-02T03:00:00Z'},
      {'revision': 4, 'action': 'reassignment_closed', 'cancelled': true,
        'actor_uid': 'Diver A', 'at': '2026-10-02T04:00:00Z'},
    ]);
    expect(history.map((e) => e['action']),
        ['requested', 'proposed', 'proposal_cancelled', 'cancelled']);
    expect((history[1]['state'] as Map)['replacement_name'], 'Diver B');
    expect(history.first['at'], isA<DateTime>());
  });

  test('the latest Expert assessment is read for display', () {
    final assessment = SupabaseFollowUpService.assessmentFromRow({
      'level': 'High',
      'validated_by': 'Expert E',
      'validated_at': '2026-10-06T01:00:00Z',
      'survey_date': '2026-10-04T16:00:00Z',
    });
    expect(assessment, isNotNull);
    expect(assessment!.level, 'High');
    expect(assessment.isHigh, isTrue);
    expect(SupabaseFollowUpService.assessmentFromRow({'level': 'Unknown'}),
        isNull);
  });
}
