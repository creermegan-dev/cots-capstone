import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/follow_up_monitoring_model.dart';
import 'supabase_follow_up_service.dart';

/// One line in the staff "Monthly Visits" list: either a visit a Diver
/// submitted, or an assigned site with no visit in the chosen month.
class MonthlyVisitRow {
  const MonthlyVisitRow({
    required this.areaCode,
    required this.siteName,
    required this.diverName,
    this.survey,
  });

  final String areaCode;
  final String siteName;
  final String diverName;

  /// Null when the site has no visit in the chosen month.
  final FollowUpSurveyModel? survey;

  bool get missing => survey == null;
  DateTime? get date => survey?.surveyDate;

  /// Confirmed COTS (Supabase), or the Diver's own count when unknown.
  int? get cotsCounted =>
      survey == null ? null : (survey!.confirmedCount ?? survey!.fieldObservedCount);

  int get waiting => survey?.waitingCount ?? 0;

  String get statusLabel {
    final s = survey;
    if (s == null) return 'No visit';
    return switch (followUpSurveyStatusFromServer(
        s.serverStatus ?? '', s, const [])) {
      FollowUpSurveyStatus.completed => 'Completed',
      FollowUpSurveyStatus.pendingValidation => 'Waiting for Expert',
      FollowUpSurveyStatus.needsCorrection => 'Needs correction',
      FollowUpSurveyStatus.submitted => 'Submitted',
    };
  }
}

/// Read-only data for the staff Monthly Visits tab. Uses the existing
/// database functions only (nothing is written).
class MonthlyVisitsData {
  const MonthlyVisitsData({required this.assignments, required this.surveys});

  final List<FollowUpAssignmentModel> assignments;
  final List<FollowUpSurveyModel> surveys;

  static bool sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  /// Sites that have a visit, newest month first.
  List<DateTime> get months {
    final set = <DateTime>{
      for (final s in surveys) DateTime(s.surveyDate.year, s.surveyDate.month),
    };
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  List<String> get siteNames {
    final names = <String>{
      for (final a in assignments) a.areaName,
      for (final s in surveys) s.areaName,
    }..removeWhere((n) => n.trim().isEmpty);
    return names.toList()..sort();
  }

  /// Rows for [month] (null = all months). For a single month, every assigned
  /// site without a visit that month is listed as "No visit this month",
  /// unless the site was assigned after that month.
  List<MonthlyVisitRow> rowsFor(DateTime? month, {String? site}) {
    final rows = <MonthlyVisitRow>[];
    for (final s in surveys) {
      if (month != null && !sameMonth(s.surveyDate, month)) continue;
      if (site != null && s.areaName != site) continue;
      rows.add(MonthlyVisitRow(
        areaCode: s.areaId,
        siteName: s.areaName,
        diverName: s.submittedBy.trim().isEmpty ? 'Diver' : s.submittedBy,
        survey: s,
      ));
    }
    rows.sort((a, b) => b.date!.compareTo(a.date!));
    if (month != null) {
      final visited = {for (final r in rows) r.areaCode};
      final missing = <MonthlyVisitRow>[];
      for (final a in assignments) {
        if (site != null && a.areaName != site) continue;
        if (visited.contains(a.areaId)) continue;
        final assigned = DateTime(a.initialDate.year, a.initialDate.month);
        if (assigned.isAfter(DateTime(month.year, month.month))) continue;
        missing.add(MonthlyVisitRow(
          areaCode: a.areaId,
          siteName: a.areaName,
          diverName: a.primaryDiverName.trim().isEmpty
              ? 'Diver'
              : a.primaryDiverName,
        ));
      }
      missing.sort((a, b) => a.siteName.compareTo(b.siteName));
      rows.addAll(missing);
    }
    return rows;
  }
}

abstract final class MonthlyVisitsApi {
  /// Loads every assigned site and its visits for staff (Admin/Expert).
  static Future<MonthlyVisitsData> load() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from('follow_up_assignments')
        .select('monitoring_areas(code)');
    final codes = <String>{
      for (final row in rows)
        if (row['monitoring_areas'] is Map &&
            (row['monitoring_areas'] as Map)['code'] != null)
          (row['monitoring_areas'] as Map)['code'].toString(),
    }.toList()
      ..sort();
    final results = await Future.wait([
      for (final code in codes)
        Future.wait([
          SupabaseFollowUpService.assignments(areaCode: code),
          SupabaseFollowUpService.surveys(areaCode: code),
        ]),
    ]);
    final assignments = <FollowUpAssignmentModel>[];
    final surveys = <FollowUpSurveyModel>[];
    final seen = <String>{};
    for (final pair in results) {
      assignments.addAll(pair[0] as List<FollowUpAssignmentModel>);
      for (final s in pair[1] as List<FollowUpSurveyModel>) {
        if (seen.add(s.id)) surveys.add(s);
      }
    }
    return MonthlyVisitsData(assignments: assignments, surveys: surveys);
  }
}
