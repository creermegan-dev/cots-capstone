import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/site_partner.dart';

/// Stage 10: the site partner calls behind the screens. The database checks
/// who may do what; the widgets take this class so tests can replace it.
class SitePartnerApi {
  const SitePartnerApi();

  SupabaseClient get _client => Supabase.instance.client;

  List<Map<String, dynamic>> _rows(Object? value) => [
        for (final row in (value as List?) ?? const [])
          Map<String, dynamic>.from(row as Map),
      ];

  /// The signed-in person's sites with their main Divers.
  Future<List<SiteTeam>> teams() async => [
        for (final row in _rows(await _client.rpc<dynamic>('site_teams_json')))
          SiteTeam.fromJson(row),
      ];

  /// Requests the signed-in person may see (the Expert sees all), oldest
  /// first among those waiting for the Expert.
  Future<List<SitePartnerRequest>> requests() async => [
        for (final row in _rows(
            await _client.rpc<dynamic>('site_partner_requests_json')))
          SitePartnerRequest.fromJson(row),
      ];

  /// Verified Divers that Main Diver 1 can invite: {uid, name}.
  Future<List<Map<String, dynamic>>> choices(String areaCode) async => _rows(
      await _client.rpc<dynamic>('site_partner_choices_json',
          params: {'area_code': areaCode}));

  Future<void> invite(String areaCode, String diverUid) =>
      _client.rpc<dynamic>('invite_site_partner',
          params: {'area_code': areaCode, 'diver': diverUid});

  Future<String> respond(String requestId, {required bool accept}) async =>
      (await _client.rpc<dynamic>('respond_site_partner_invite',
              params: {'rid': requestId, 'accept': accept}))
          ?.toString() ??
      '';

  /// Stage 11: the site partner leaves the site.
  Future<void> leave(String areaCode) =>
      _client.rpc<dynamic>('leave_site', params: {'area_code': areaCode});

  Future<String> decide(String requestId, {required bool approve}) async =>
      (await _client.rpc<dynamic>('decide_site_partner',
              params: {'rid': requestId, 'approve': approve}))
          ?.toString() ??
      '';
}
