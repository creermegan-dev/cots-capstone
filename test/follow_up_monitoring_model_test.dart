import 'package:cots_monitor/models/follow_up_monitoring_model.dart';
import 'package:cots_monitor/models/capture_model.dart';
import 'package:cots_monitor/models/cots_confidence_policy.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/models/davao_gulf_geography.dart';
import 'package:cots_monitor/services/zone_assignment_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('monitoring zone linkage', () {
    test('missing, invalid and unmapped GPS never selects a monitoring site',
        () {
      expect(ZoneAssignmentService.resolveMonitoringArea(), isNull);
      expect(
          ZoneAssignmentService.resolveMonitoringArea(
              latitude: double.nan, longitude: 125),
          isNull);
      expect(
          ZoneAssignmentService.resolveMonitoringArea(
              latitude: 95, longitude: 125),
          isNull);
      expect(
          ZoneAssignmentService.resolveMonitoringArea(
              latitude: 0, longitude: 0),
          isNull);
    });
    test('unique mapped sites resolve to their stable site identity', () {
      var resolved = 0;
      for (final site in DavaoGulfGeography.allBarangays) {
        final result = ZoneAssignmentService.resolveMonitoringArea(
            latitude: site.centroid.latitude,
            longitude: site.centroid.longitude);
        if (result == null) continue;
        expect(result.barangay.id, site.id);
        expect(result.barangay.siteCode, site.siteCode);
        resolved++;
      }
      expect(resolved, greaterThan(0));
    });
  });
  group('buildFollowUpMonthHistory', () {
    test('marks baseline, missed, current, and next calendar months', () {
      final entries = buildFollowUpMonthHistory(
        initialDate: DateTime(2025, 9, 18, 16),
        surveys: const [],
        currentDate: DateTime(2025, 10, 8, 12),
      );

      expect(
        entries.map((entry) => entry.status),
        [
          FollowUpMonthStatus.monitored,
          FollowUpMonthStatus.awaiting,
          FollowUpMonthStatus.upcoming,
        ],
      );
      expect(
        entries.map((entry) => entry.month),
        [DateTime(2025, 9), DateTime(2025, 10), DateTime(2025, 11)],
      );
    });

    test('marks months with one or more saved surveys as monitored', () {
      final areaSurvey = _survey(
        id: 'survey-1',
        date: DateTime(2025, 10, 3),
      );
      final secondSurvey = _survey(
        id: 'survey-2',
        date: DateTime(2025, 10, 28),
      );

      final entries = buildFollowUpMonthHistory(
        initialDate: DateTime(2025, 9, 18),
        surveys: [areaSurvey, secondSurvey],
        completedSurveyIds: {'survey-1', 'survey-2'},
        currentDate: DateTime(2025, 11, 8),
      );

      expect(entries[1].status, FollowUpMonthStatus.monitored);
      expect(entries[1].surveys, hasLength(2));
      expect(entries[2].status, FollowUpMonthStatus.awaiting);
      expect(entries[3].status, FollowUpMonthStatus.upcoming);
    });

    test('uses local calendar month for UTC dates near month boundaries', () {
      final initial = DateTime.utc(2025, 10, 1, 0, 30);
      final current = DateTime.utc(2025, 10, 2, 0, 30);

      final entries = buildFollowUpMonthHistory(
        initialDate: initial,
        surveys: const [],
        currentDate: current,
      );

      expect(entries.first.month,
          DateTime(initial.toLocal().year, initial.toLocal().month));
    });
  });
  test('submitted visits do not complete the month', () {
    final entries = buildFollowUpMonthHistory(
      initialDate: DateTime(2025, 9),
      surveys: [_survey(id: 'visit', date: DateTime(2025, 10, 5))],
      currentDate: DateTime(2025, 11, 2),
    );
    expect(entries[1].status, FollowUpMonthStatus.notRecorded);
    expect(entries[1].surveys, hasLength(1));
  });
  test('calendar date survives a timestamp with a different UTC date', () {
    final survey = FollowUpSurveyModel.fromMap({
      'survey_date': '2025-09-30T16:00:00Z',
      'survey_calendar_date': '2025-10-01',
    }, id: 'visit');
    expect(survey.surveyDate, DateTime(2025, 10, 1));
    expect(survey.toFirestore()['survey_calendar_date'], '2025-10-01');
  });
  group('original diver chronology', () {
    test('selects earliest saved detection regardless of input order', () {
      final first =
          _capture(id: 'first', uid: 'original', date: DateTime(2025, 9));
      final later =
          _capture(id: 'later', uid: 'other', date: DateTime(2025, 10));
      expect(originalFollowUpDetection([later, first])?.uid, 'original');
    });
    test('does not guess when timestamps tie across divers', () {
      expect(
          originalFollowUpDetection([
            _capture(uid: 'one'),
            _capture(uid: 'two'),
          ]),
          isNull);
    });
    test('does not guess when identity or chronology is missing', () {
      expect(originalFollowUpDetection([_capture(uid: '')]), isNull);
      expect(originalFollowUpDetection([_capture(dateMissing: true)]), isNull);
    });
  });
  group('survey completion', () {
    final survey = _survey(id: 'visit', date: DateTime(2025, 10));
    test('missing image metadata stays submitted', () {
      expect(followUpSurveyStatus(survey, []), FollowUpSurveyStatus.submitted);
    });
    test('uncertain AI remains pending', () {
      expect(followUpSurveyStatus(survey, [_capture(confidence: .6)]),
          FollowUpSurveyStatus.pendingValidation);
    });
    test('auto accepted AI completes monitoring', () {
      expect(followUpSurveyStatus(survey, [_capture()]),
          FollowUpSurveyStatus.completed);
    });
    test(
        'expert decisions resolve pending counts independently of field counts',
        () {
      expect(
          followUpSurveyStatus(survey, [
            _capture(
                confidence: .6, decisions: [PerCotsAdminDecision.confirmed])
          ]),
          FollowUpSurveyStatus.completed);
      expect(survey.fieldObservedCount, 2);
    });
    test('zero COTS survey completes without a cleared designation', () {
      final status =
          followUpSurveyStatus(survey, [_capture(count: 0, confidence: 0)]);
      expect(status, FollowUpSurveyStatus.completed);
      expect(followUpSurveyStatusLabel(status), 'Completed Monitoring');
    });
    test('rejected or wrong-area evidence never completes monitoring', () {
      expect(followUpSurveyStatus(survey, [_capture(rejected: true)]),
          FollowUpSurveyStatus.needsCorrection);
      expect(followUpSurveyStatus(survey, [_capture(areaId: 'other')]),
          FollowUpSurveyStatus.needsCorrection);
      expect(followUpSurveyStatus(survey, [_capture(uid: 'other')]),
          FollowUpSurveyStatus.needsCorrection);
    });
    test('survey records retain field, AI and elimination values separately',
        () {
      final record = ScanRecordModel.fromFollowUpSurvey(survey,
          status: FollowUpSurveyStatus.completed);
      expect(record.userStatusLabel, 'Completed Monitoring');
      expect(record.toAdminTableRow(1).density, isNull);
      expect(record.toAdminTableRow(1).risk, 'Not validated');
      expect(record.followUpSurvey!.fieldEliminatedCount, 1);
      expect(record.followUpSurvey!.fieldObservedCount, 2);
      expect(record.followUpSurvey!.aiDetectedCount, 0);
    });
    test(
        'follow-up images cannot contribute invented density to admin summaries',
        () {
      final followUp = ScanRecordModel.fromCapture(_capture(surveyId: 'visit'));
      expect(followUp.toAdminTableRow(1).density, isNull);
      expect(_capture(surveyId: 'visit').toAdminTableRow(1).density, isNull);
      expect(_capture().toAdminTableRow(1).density, isNotNull);
    });
    test('an image linked to a different visit cannot complete monitoring', () {
      expect(
          followUpSurveyStatus(survey, [_capture(surveyId: 'another-visit')]),
          FollowUpSurveyStatus.needsCorrection);
    });
  });
}

CaptureModel _capture({
  String id = 'image',
  String uid = 'diver-1',
  DateTime? date,
  bool dateMissing = false,
  String areaId = 'area-1',
  String surveyId = '',
  double confidence = .9,
  int count = 1,
  bool rejected = false,
  List<PerCotsAdminDecision> decisions = const [],
}) =>
    CaptureModel(
      id: id,
      uid: uid,
      submittedBy: uid,
      imageName: 'reef.jpg',
      aiDetectedCount: count,
      confidence: confidence,
      captureSource: 'GoPro Underwater Image',
      zone: 'A-01',
      notes: '',
      submittedAt: dateMissing ? null : date ?? DateTime(2025, 9),
      monitoringAreaId: areaId,
      followUpSurveyId: surveyId,
      adminRejected: rejected,
      adminCotsDecisions: decisions,
    );

FollowUpSurveyModel _survey({
  required String id,
  required DateTime date,
}) {
  return FollowUpSurveyModel(
    id: id,
    areaId: 'area-1',
    uid: 'diver-1',
    submittedBy: 'Diver One',
    areaName: 'Zone A · A-01',
    barangay: 'Barangay One',
    municipality: 'Municipality One',
    surveyDate: date,
    fieldObservedCount: 2,
    fieldEliminatedCount: 1,
    captureIds: const ['image'],
    submittedAt: date,
  );
}
