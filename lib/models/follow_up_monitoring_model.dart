import 'package:cloud_firestore/cloud_firestore.dart';
import 'capture_model.dart';
import 'cots_confidence_policy.dart';
import 'record_collection.dart';

enum FollowUpSurveyStatus {
  submitted,
  pendingValidation,
  completed,
  needsCorrection
}

FollowUpSurveyStatus followUpSurveyStatus(
  FollowUpSurveyModel survey,
  List<CaptureModel> captures,
) {
  // Supabase decides completion on the server; use its status when present.
  final serverStatus = survey.serverStatus;
  if (serverStatus != null) {
    return followUpSurveyStatusFromServer(serverStatus, survey, captures);
  }
  if (survey.captureIds.isEmpty) return FollowUpSurveyStatus.submitted;
  final byId = {for (final capture in captures) capture.id: capture};
  var pending = false;
  for (final id in survey.captureIds) {
    final capture = byId[id];
    if (capture == null) return FollowUpSurveyStatus.submitted;
    if (capture.uid != survey.uid ||
        capture.monitoringAreaId != survey.areaId ||
        (capture.followUpSurveyId.isNotEmpty &&
            capture.followUpSurveyId != survey.id) ||
        capture.adminRejected) {
      return FollowUpSurveyStatus.needsCorrection;
    }
    if (capture.adminConfirmed) continue;
    if (capture.aiDetectedCount == 0) continue;
    final items = CotsConfidencePolicy.buildDetectionItems(
      count: capture.aiDetectedCount,
      averagePercent: capture.confidencePercent,
      boxes: capture.detectionBoxes.isEmpty ? null : capture.detectionBoxes,
      imageWidth: capture.imageWidth,
      imageHeight: capture.imageHeight,
    );
    for (var i = 0; i < items.length; i++) {
      final decision = i < capture.adminCotsDecisions.length
          ? capture.adminCotsDecisions[i]
          : null;
      if (decision == PerCotsAdminDecision.confirmed ||
          decision == PerCotsAdminDecision.rejected) {
        continue;
      }
      if (items[i].confidencePercent < CotsConfidencePolicy.adminReviewMin) {
        return FollowUpSurveyStatus.needsCorrection;
      }
      if (items[i].confidencePercent < CotsConfidencePolicy.autoApproveMin) {
        pending = true;
      }
    }
  }
  return pending
      ? FollowUpSurveyStatus.pendingValidation
      : FollowUpSurveyStatus.completed;
}

/// Supabase visit status → the labels the app already shows. A pending visit
/// with a rejected detection record needs correction, as in Firebase.
FollowUpSurveyStatus followUpSurveyStatusFromServer(
  String serverStatus,
  FollowUpSurveyModel survey,
  List<CaptureModel> captures,
) {
  switch (serverStatus) {
    case 'completed':
      return FollowUpSurveyStatus.completed;
    case 'historical_only':
      return FollowUpSurveyStatus.needsCorrection;
    case 'pending_late_review':
    case 'pending_authorization_review':
      return FollowUpSurveyStatus.pendingValidation;
  }
  final ids = survey.captureIds.toSet();
  if (captures.any((c) => ids.contains(c.id) && c.adminRejected)) {
    return FollowUpSurveyStatus.needsCorrection;
  }
  return survey.captureIds.isEmpty
      ? FollowUpSurveyStatus.submitted
      : FollowUpSurveyStatus.pendingValidation;
}

String followUpSurveyStatusLabel(FollowUpSurveyStatus status) =>
    switch (status) {
      FollowUpSurveyStatus.submitted => 'Submitted',
      FollowUpSurveyStatus.pendingValidation => 'Pending Validation',
      FollowUpSurveyStatus.completed => 'Completed Monitoring',
      FollowUpSurveyStatus.needsCorrection => 'Needs Correction',
    };

class FollowUpAssignmentModel {
  const FollowUpAssignmentModel({
    required this.areaId,
    required this.areaName,
    required this.barangay,
    required this.municipality,
    required this.primaryDiverUid,
    required this.primaryDiverName,
    required this.initialCaptureId,
    required this.initialDate,
    required this.initialDetectedCount,
    this.initialCollection = RecordCollection.captures,
  });

  final String areaId;
  final String areaName;
  final String barangay;
  final String municipality;
  final String primaryDiverUid;
  final String primaryDiverName;
  final String initialCaptureId;
  final DateTime initialDate;
  final int initialDetectedCount;
  final String initialCollection;

  factory FollowUpAssignmentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return FollowUpAssignmentModel.fromMap(
      doc.data() ?? const {},
      areaId: doc.id,
    );
  }

  factory FollowUpAssignmentModel.fromMap(
    Map<String, dynamic> map, {
    required String areaId,
  }) {
    return FollowUpAssignmentModel(
      areaId: map['area_id'] as String? ?? areaId,
      areaName: map['area_name'] as String? ?? '',
      barangay: map['barangay'] as String? ?? '',
      municipality: map['municipality'] as String? ?? '',
      primaryDiverUid: map['primary_diver_uid'] as String? ?? '',
      primaryDiverName: map['primary_diver_name'] as String? ?? '',
      initialCaptureId: map['initial_capture_id'] as String? ?? '',
      initialDate: _dateFromDynamic(map['initial_date']) ?? DateTime(1970),
      initialDetectedCount: _intFromDynamic(map['initial_detected_count']),
      initialCollection:
          map['initial_collection'] as String? ?? RecordCollection.captures,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'area_id': areaId,
        'area_name': areaName,
        'barangay': barangay,
        'municipality': municipality,
        'primary_diver_uid': primaryDiverUid,
        'primary_diver_name': primaryDiverName,
        'initial_capture_id': initialCaptureId,
        'initial_date': Timestamp.fromDate(initialDate.toUtc()),
        'initial_detected_count': initialDetectedCount,
        'initial_collection': initialCollection,
        'created_at': FieldValue.serverTimestamp(),
      };
}

class FollowUpSurveyModel {
  const FollowUpSurveyModel({
    required this.id,
    required this.areaId,
    required this.uid,
    required this.submittedBy,
    required this.areaName,
    required this.barangay,
    required this.municipality,
    required this.surveyDate,
    required this.fieldObservedCount,
    required this.fieldEliminatedCount,
    required this.captureIds,
    required this.submittedAt,
    this.latitude,
    this.longitude,
    this.surveyedAreaSquareMeters,
    this.eliminationMethod = '',
    this.notes = '',
    this.aiDetectedCount = 0,
    this.serverStatus,
    this.densityPerHectare,
    this.calculatedLevel,
    this.assessedLevel,
    this.confirmedCount,
    this.waitingCount,
    this.earlyVisitNote,
  });

  final String id;
  final String areaId;
  final String uid;
  final String submittedBy;
  final String areaName;
  final String barangay;
  final String municipality;
  final DateTime surveyDate;
  final int fieldObservedCount;
  final int fieldEliminatedCount;
  final List<String> captureIds;
  final DateTime? submittedAt;
  final double? latitude;
  final double? longitude;
  final double? surveyedAreaSquareMeters;
  final String eliminationMethod;
  final String notes;
  final int aiDetectedCount;

  /// Visit status decided by Supabase (null for Firebase visits).
  final String? serverStatus;

  /// COTS per hectare and its level, calculated by Supabase.
  final double? densityPerHectare;
  final String? calculatedLevel;

  /// Level confirmed by the Expert for this visit, if any.
  final String? assessedLevel;

  /// COTS in the visit photos confirmed so far (Expert-rejected COTS are not
  /// counted), and COTS still waiting for the Expert. Supabase only.
  final int? confirmedCount;
  final int? waitingCount;

  /// Stage 5: set by Supabase when the visit was made within 2 days after an
  /// injection in the zone ("Visit within 2 days of an injection on ...").
  /// Null otherwise and for Firebase visits.
  final String? earlyVisitNote;

  factory FollowUpSurveyModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return FollowUpSurveyModel.fromMap(doc.data() ?? const {}, id: doc.id);
  }

  factory FollowUpSurveyModel.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    final gps = map['gps'];
    final gpsMap = gps is Map ? Map<String, dynamic>.from(gps) : const {};
    final captureIdsValue = map['capture_ids'];
    return FollowUpSurveyModel(
      id: id,
      areaId: map['area_id'] as String? ?? '',
      uid: map['uid'] as String? ?? '',
      submittedBy: map['submitted_by'] as String? ?? '',
      areaName: map['area_name'] as String? ?? '',
      barangay: map['barangay'] as String? ?? '',
      municipality: map['municipality'] as String? ?? '',
      surveyDate:
          _dateFromDynamic(map['survey_calendar_date'] ?? map['survey_date']) ??
              DateTime(1970),
      fieldObservedCount: _intFromDynamic(map['field_observed_count']),
      fieldEliminatedCount: _intFromDynamic(map['field_eliminated_count']),
      captureIds: captureIdsValue is List
          ? captureIdsValue.whereType<String>().toList(growable: false)
          : const [],
      submittedAt: _dateFromDynamic(map['submitted_at']),
      latitude: _doubleFromDynamic(gpsMap['latitude']),
      longitude: _doubleFromDynamic(gpsMap['longitude']),
      surveyedAreaSquareMeters:
          _doubleFromDynamic(map['surveyed_area_square_meters']),
      eliminationMethod: map['elimination_method'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      aiDetectedCount: _intFromDynamic(map['ai_detected_count']),
      serverStatus: map['status'] as String?,
      densityPerHectare: _doubleFromDynamic(map['density_per_ha']),
      calculatedLevel: map['calculated_level'] as String?,
      assessedLevel: map['assessed_level'] as String?,
      confirmedCount: _nullableIntFromDynamic(map['confirmed_count']),
      waitingCount: _nullableIntFromDynamic(map['waiting_count']),
      earlyVisitNote: (map['early_visit_note'] as String?)?.trim().isEmpty ?? true
          ? null
          : (map['early_visit_note'] as String).trim(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'area_id': areaId,
        'uid': uid,
        'submitted_by': submittedBy,
        'area_name': areaName,
        'barangay': barangay,
        'municipality': municipality,
        'survey_date': Timestamp.fromDate(surveyCalendarInstant(surveyDate)),
        'survey_calendar_date': surveyCalendarDate(surveyDate),
        'field_observed_count': fieldObservedCount,
        'field_eliminated_count': fieldEliminatedCount,
        'capture_ids': captureIds,
        'gps': {'latitude': latitude, 'longitude': longitude},
        if (surveyedAreaSquareMeters != null)
          'surveyed_area_square_meters': surveyedAreaSquareMeters,
        'elimination_method': eliminationMethod,
        'notes': notes,
        'ai_detected_count': aiDetectedCount,
        'submitted_at': FieldValue.serverTimestamp(),
      };
}

String surveyCalendarDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// The selected survey calendar day starts at midnight in the Philippines.
DateTime surveyCalendarInstant(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day)
        .subtract(const Duration(hours: 8));

/// Null means chronology or identity is insufficient to select an original diver.
CaptureModel? originalFollowUpDetection(List<CaptureModel> detections) {
  if (detections.isEmpty ||
      detections.any((capture) =>
          capture.submittedAt == null || capture.uid.trim().isEmpty)) {
    return null;
  }
  final ordered = [...detections]
    ..sort((a, b) => a.submittedAt!.compareTo(b.submittedAt!));
  final first = ordered.first;
  if (ordered.any((capture) =>
      capture.submittedAt == first.submittedAt && capture.uid != first.uid)) {
    return null;
  }
  return first;
}

enum FollowUpMonthStatus { monitored, awaiting, notRecorded, upcoming }

class FollowUpMonthEntry {
  const FollowUpMonthEntry({
    required this.month,
    required this.status,
    this.surveys = const [],
  });

  final DateTime month;
  final FollowUpMonthStatus status;
  final List<FollowUpSurveyModel> surveys;

  String get statusLabel => switch (status) {
        FollowUpMonthStatus.monitored => 'Monitored',
        FollowUpMonthStatus.awaiting => 'Awaiting Follow-up',
        FollowUpMonthStatus.notRecorded => 'Not Recorded',
        FollowUpMonthStatus.upcoming => 'Upcoming',
      };
}

List<FollowUpMonthEntry> buildFollowUpMonthHistory({
  required DateTime initialDate,
  required List<FollowUpSurveyModel> surveys,
  required DateTime currentDate,
  Set<String>? completedSurveyIds,
}) {
  final localInitialDate = initialDate.toLocal();
  final localCurrentDate = currentDate.toLocal();
  final initialMonth = DateTime(localInitialDate.year, localInitialDate.month);
  final currentMonth = DateTime(localCurrentDate.year, localCurrentDate.month);
  final lastMonth = DateTime(currentMonth.year, currentMonth.month + 1);
  final surveysByMonth = <int, List<FollowUpSurveyModel>>{};

  for (final survey in surveys) {
    final date = survey.surveyDate.toLocal();
    final key = date.year * 100 + date.month;
    surveysByMonth.putIfAbsent(key, () => []).add(survey);
  }

  final entries = <FollowUpMonthEntry>[];
  for (var month = initialMonth;
      !month.isAfter(lastMonth);
      month = DateTime(month.year, month.month + 1)) {
    final key = month.year * 100 + month.month;
    final visits = surveysByMonth[key] ?? const [];
    final isInitialMonth =
        month.year == initialMonth.year && month.month == initialMonth.month;

    final status = month.isAfter(currentMonth)
        ? FollowUpMonthStatus.upcoming
        : visits.any((survey) =>
                    completedSurveyIds?.contains(survey.id) ?? false) ||
                isInitialMonth
            ? FollowUpMonthStatus.monitored
            : month.year == currentMonth.year &&
                    month.month == currentMonth.month
                ? FollowUpMonthStatus.awaiting
                : FollowUpMonthStatus.notRecorded;

    entries.add(
      FollowUpMonthEntry(
        month: month,
        status: status,
        surveys: List.unmodifiable(visits),
      ),
    );
  }

  return List.unmodifiable(entries);
}

DateTime? _dateFromDynamic(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// The visit's one "COTS found and removed" value (taken from the photos),
/// with the Expert-confirmed part when Supabase reports it.
String followUpCountSummary(FollowUpSurveyModel survey) =>
    _hasSeparateOlderCounts(survey)
        ? 'COTS found: ${survey.fieldObservedCount}, '
            'removed: ${survey.fieldEliminatedCount}'
        : 'COTS found and removed: ${followUpCountValue(survey)}';

/// The value alone ("4 (3 confirmed)"), for screens that show their own label.
String followUpCountValue(FollowUpSurveyModel survey) {
  if (_hasSeparateOlderCounts(survey)) {
    return '${survey.fieldObservedCount} found, '
        '${survey.fieldEliminatedCount} removed';
  }
  final detail = followUpCountDetail(survey);
  return '${survey.fieldEliminatedCount}${detail == null ? '' : ' ($detail)'}';
}

/// Firebase and older visits stored two different typed values.
bool _hasSeparateOlderCounts(FollowUpSurveyModel survey) =>
    survey.confirmedCount == null &&
    survey.fieldObservedCount != survey.fieldEliminatedCount;

/// The Expert-confirmed part of a visit's count ("3 confirmed, 1 waiting for
/// Expert"), or null when Supabase did not report it or no COTS were found.
String? followUpCountDetail(FollowUpSurveyModel survey) {
  final confirmed = survey.confirmedCount;
  if (confirmed == null || survey.fieldEliminatedCount == 0) return null;
  final waiting = survey.waitingCount ?? 0;
  return '$confirmed confirmed'
      '${waiting > 0 ? ', $waiting waiting for Expert' : ''}';
}

int? _nullableIntFromDynamic(Object? value) =>
    value == null ? null : _intFromDynamic(value);

int _intFromDynamic(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double? _doubleFromDynamic(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
