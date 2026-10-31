import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/area_handover.dart';
import 'follow_up_reassignment_repository.dart';

/// Stage 4: the handover calls behind the screens. The database checks who
/// may do what; the widgets take this class so tests can replace it.
class AreaHandoverApi {
  const AreaHandoverApi();

  SupabaseClient get _client => Supabase.instance.client;

  List<Map<String, dynamic>> _rows(Object? value) => [
        for (final row in (value as List?) ?? const [])
          Map<String, dynamic>.from(row as Map),
      ];

  Future<List<AreaHandover>> list() async => [
        for (final row
            in _rows(await _client.rpc<dynamic>('area_handovers_json')))
          AreaHandover.fromJson(row),
      ];

  Future<List<AreaMissedMonths>> missedMonths() async => [
        for (final row
            in _rows(await _client.rpc<dynamic>('area_missed_months_json')))
          AreaMissedMonths.fromJson(row),
      ];

  Future<void> request(String areaCode, String reason, String note) =>
      _client.rpc<dynamic>('request_area_handover', params: {
        'area_code': areaCode,
        'reason_text': reason.trim(),
        'note_text': note.trim(),
      });

  Future<void> start(String areaCode) => _client
      .rpc<dynamic>('start_area_handover', params: {'area_code': areaCode});

  Future<void> offer(String handoverId, String diverUid) =>
      _client.rpc<dynamic>('offer_area_handover',
          params: {'hid': handoverId, 'diver': diverUid});

  Future<String> respond(String offerId, {required bool accept}) async =>
      (await _client.rpc<dynamic>('respond_area_handover',
              params: {'oid': offerId, 'accept': accept}))
          ?.toString() ??
      '';

  Future<void> cancel(String handoverId) =>
      _client.rpc<dynamic>('cancel_area_handover', params: {'hid': handoverId});

  /// Verified field Divers the Expert can choose from.
  Future<List<Map<String, dynamic>>> directory() =>
      FollowUpReassignmentRepository.directory();
}
