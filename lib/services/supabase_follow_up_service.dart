import 'dart:async';
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/davao_gulf_geography.dart';
import '../models/follow_up_infestation_assessment.dart';
import '../models/follow_up_monitoring_model.dart';
import '../models/follow_up_reassignment.dart';

/// Follow-up monitoring on Supabase.
///
/// The database owns the rules (see migration
/// 20261030000500_follow_up_app_support.sql): the original Diver is set when
/// their detection is first confirmed in an area, each month starts with the
/// original Diver, and the Expert can propose a replacement for one month.
/// This class only calls those database functions and converts the results
/// into the models the screens already use.
abstract final class SupabaseFollowUpService {
  static SupabaseClient get _client => Supabase.instance.client;
  static const refreshInterval = Duration(seconds: 15);

  // ---------- Reading ----------

  /// The caller's areas (original Diver or this month's replacement), or one
  /// area by its code.
  static Future<List<FollowUpAssignmentModel>> assignments({
    String? areaCode,
  }) async {
    final rows = await _client.rpc<dynamic>(
      'follow_up_assignments_json',
      params: {'area_code': areaCode},
    );
    return [for (final row in _rows(rows)) assignmentFromRow(row)];
  }

  static Future<List<FollowUpSurveyModel>> surveys({
    String? areaCode,
    bool mineOnly = false,
  }) async {
    final rows = await _client.rpc<dynamic>(
      'follow_up_surveys_json',
      params: {'area_code': areaCode, 'mine_only': mineOnly},
    );
    return [for (final row in _rows(rows)) surveyFromRow(row)];
  }

  static Future<bool> canSubmit(String areaCode, DateTime visitDate) async {
    final result = await _client.rpc<dynamic>(
      'follow_up_can_submit',
      params: {'area_code': areaCode, 'visit_date': dateOnly(visitDate)},
    );
    return result == true;
  }

  static Future<List<FollowUpReassignment>> reassignments({
    String? requestId,
  }) async {
    final rows = await _client.rpc<dynamic>(
      'follow_up_reassignments_json',
      params: {'request_id': requestId},
    );
    return [for (final row in _rows(rows)) reassignmentFromRow(row)];
  }

  static Future<List<Map<String, dynamic>>> history(String requestId) async {
    final rows = await _client.rpc<dynamic>(
      'follow_up_reassignment_history',
      params: {'request_id': requestId},
    );
    return historyFromRows(_rows(rows));
  }

  /// Approved field Divers the Expert can propose as a replacement.
  static Future<List<Map<String, dynamic>>> directory() async {
    final rows = await _client.rpc<dynamic>('eligible_personnel');
    return [
      for (final row in _rows(rows))
        {
          'uid': row['id']?.toString() ?? '',
          'name': row['full_name']?.toString() ?? '',
          'eligible': true,
        }
    ];
  }

  static Future<FollowUpInfestationAssessment?> latestAssessment(
    String areaCode,
  ) async {
    final row = await _client.rpc<dynamic>(
      'latest_area_assessment',
      params: {'area_code': areaCode},
    );
    return row is Map ? assessmentFromRow(Map<String, dynamic>.from(row)) : null;
  }

  /// Expert: completed visits that still need a confirmed level.
  static Future<List<FollowUpSurveyModel>> visitsToAssess() async {
    final rows = await _client.rpc<dynamic>('follow_up_visits_to_assess');
    return [for (final row in _rows(rows)) surveyFromRow(row)];
  }

  // ---------- Actions ----------

  /// Expert: confirm the calculated level, or choose another with a reason.
  static Future<void> confirmAssessment({
    required String surveyId,
    required String level,
    String reason = '',
  }) =>
      _client.rpc<dynamic>('confirm_follow_up_assessment', params: {
        'sid': surveyId,
        'chosen_level': level,
        'reason_text': reason.trim(),
      });

  static Future<String> submitSurvey({
    required String surveyId,
    required String areaCode,
    required DateTime visitDate,
    required int observed,
    required int eliminated,
    required String method,
    required double? surveyedSquareMeters,
    required List<String> captureIds,
    required double? latitude,
    required double? longitude,
    required String notes,
  }) async {
    final status = await _client.rpc<dynamic>(
      'submit_follow_up_survey',
      params: {
        'sid': surveyId,
        'area_code': areaCode,
        'visit_date': dateOnly(visitDate),
        'observed': observed,
        'eliminated': eliminated,
        'method': method,
        'surveyed_m2': surveyedSquareMeters,
        'capture_ids': captureIds,
        'lat': latitude,
        'lng': longitude,
        'notes_text': notes,
      },
    );
    return status?.toString() ?? 'pending';
  }

  static Future<void> request(String areaCode, String reason) =>
      _client.rpc<dynamic>('request_follow_up_reassignment',
          params: {'area_code': areaCode, 'reason_text': reason.trim()});

  static Future<void> propose(String requestId, String replacementUid) =>
      _client.rpc<dynamic>('propose_replacement',
          params: {'rid': requestId, 'replacement': replacementUid});

  static Future<void> respond(String proposalId, bool accept) =>
      _client.rpc<dynamic>('respond_replacement',
          params: {'pid': proposalId, 'accept_proposal': accept});

  /// Expert: withdraw the pending proposal so another Diver can be chosen.
  static Future<void> cancelProposal(String requestId) =>
      _client.rpc<dynamic>('close_reassignment',
          params: {'rid': requestId, 'cancel_request': false});

  /// The Diver who asked, or the Expert: cancel the whole request.
  static Future<void> cancelRequest(String requestId) =>
      _client.rpc<dynamic>('cancel_reassignment', params: {'rid': requestId});

  // ---------- Polling ----------

  /// Loads now and every [refreshInterval]; a failed load is reported but the
  /// stream keeps refreshing.
  static Stream<T> poll<T>(Future<T> Function() loader) async* {
    var first = true;
    while (true) {
      if (!first) await Future<void>.delayed(refreshInterval);
      first = false;
      try {
        yield await loader();
      } catch (error, stackTrace) {
        yield* Stream<T>.error(error, stackTrace);
      }
    }
  }

  // ---------- Conversions (pure; unit tested) ----------

  static String dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Random version-4 UUID for a new follow-up visit.
  static String newId([math.Random? random]) {
    final r = random ?? math.Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Area names exactly as the Firebase version showed them.
  static Map<String, dynamic> withAreaNames(Map<String, dynamic> row) {
    final code = row['area_id']?.toString() ?? '';
    final area = DavaoGulfGeography.barangayById(code);
    String? municipality;
    if (area != null) {
      for (final item in DavaoGulfGeography.municipalities) {
        if (item.id == area.municipalityId) municipality = item.name;
      }
    }
    return {
      ...row,
      'area_name': area == null
          ? (row['area_label']?.toString() ?? code)
          : '${area.zoneLabel} · ${area.siteCode}',
      'barangay': area?.name ?? row['barangay']?.toString() ?? '',
      'municipality': municipality ?? row['municipality']?.toString() ?? '',
    };
  }

  static FollowUpAssignmentModel assignmentFromRow(Map<String, dynamic> row) {
    final named = withAreaNames(row);
    return FollowUpAssignmentModel.fromMap(
      {
        ...named,
        'primary_diver_uid': named['primary_diver_uid']?.toString() ?? '',
        'initial_capture_id': named['initial_capture_id']?.toString() ?? '',
      },
      areaId: named['area_id']?.toString() ?? '',
    );
  }

  static FollowUpSurveyModel surveyFromRow(Map<String, dynamic> row) {
    final named = withAreaNames(row);
    return FollowUpSurveyModel.fromMap(
      {
        ...named,
        'uid': named['uid']?.toString() ?? '',
        'capture_ids': [
          for (final id in (named['capture_ids'] as List? ?? const []))
            id.toString()
        ],
      },
      id: named['id']?.toString() ?? '',
    );
  }

  static FollowUpReassignment reassignmentFromRow(Map<String, dynamic> row) {
    final named = withAreaNames(row);
    String text(String key) => named[key]?.toString() ?? '';
    int number(String key) {
      final value = named[key];
      if (value is num) return value.round();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final requestedAt =
        DateTime.tryParse(text('requested_at'))?.toUtc() ?? DateTime.now().toUtc();
    final data = <String, dynamic>{
      ...named,
      'primary_uid': text('primary_uid'),
      'primary_name': text('primary_name'),
      'responsible_uid': text('responsible_uid'),
      'requester_uid': text('requester_uid'),
      'replacement_uid': text('replacement_uid'),
      'replacement_name': text('replacement_name'),
      'expert_uid': text('expert_uid'),
      'proposal_id': text('proposal_id'),
      'reason': text('reason'),
      'status': text('status'),
      'year': number('year'),
      'month': number('month'),
      'revision': number('revision'),
      'requested_at': requestedAt,
      'participants': {
        text('primary_uid'),
        text('requester_uid'),
        if (text('replacement_uid').isNotEmpty) text('replacement_uid'),
      }.toList(),
    };
    return FollowUpReassignment(text('id'), data);
  }

  /// Database event names → the labels the history list already shows.
  static String historyAction(String action, {bool cancelled = false}) =>
      switch (action) {
        'reassignment_requested' => 'requested',
        'replacement_proposed' => 'proposed',
        'replacement_accepted' => 'accepted',
        'replacement_declined' => 'declined',
        'reassignment_closed' => cancelled ? 'cancelled' : 'proposal_cancelled',
        _ => action,
      };

  static List<Map<String, dynamic>> historyFromRows(
    List<Map<String, dynamic>> rows,
  ) =>
      [
        for (final row in rows)
          {
            'revision': (row['revision'] as num?)?.round() ?? 0,
            'action': historyAction(
              row['action']?.toString() ?? '',
              cancelled: row['cancelled'] == true,
            ),
            'actor_uid': row['actor_uid']?.toString() ?? '',
            'at': DateTime.tryParse(row['at']?.toString() ?? '')?.toLocal() ??
                row['at'],
            'state': {'replacement_name': row['replacement_name'] ?? ''},
          }
      ];

  static FollowUpInfestationAssessment? assessmentFromRow(
    Map<String, dynamic> row,
  ) =>
      FollowUpInfestationAssessment.fromMap({
        'validated_infestation_level': row['level'],
        'infestation_validated_by': row['validated_by'],
        'infestation_validated_at':
            DateTime.tryParse(row['validated_at']?.toString() ?? ''),
        'survey_date': DateTime.tryParse(row['survey_date']?.toString() ?? ''),
      });

  static List<Map<String, dynamic>> _rows(Object? value) => [
        if (value is List)
          for (final item in value)
            if (item is Map) Map<String, dynamic>.from(item)
      ];
}
