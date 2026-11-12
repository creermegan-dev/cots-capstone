import 'dart:convert';

import 'package:cots_monitor/services/supabase_record_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, Object?> _capture(int n) => {
      'id': 'capture-$n',
      'owner_id': 'diver',
      'encounter_id': 'batch-$n',
      'status': 'finalized',
      'captured_at': '2026-11-01T00:00:00Z',
      'submitted_at': '2026-11-01T01:00:00Z',
      'gps_source': 'exif',
      'confirmed_cots': 1,
      'waiting_cots': 0,
      'monitoring_areas': {'code': 'S4', 'name': 'Site 4 · Balet'},
      'detection_items': [
        {
          'id': 'item-$n',
          'item_index': 0,
          'x1': 1,
          'y1': 1,
          'x2': 20,
          'y2': 20,
          'confidence': .9
        }
      ],
      'expert_decisions': [],
    };

void main() {
  late SupabaseClient client;
  late List<http.Request> requests;
  var failSecondPage = false;
  setUp(() {
    requests = [];
    failSecondPage = false;
    client = SupabaseClient('https://reports.example.invalid', 'fixture-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      requests.add(request);
      final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
      if (failSecondPage && offset > 0) {
        return http.Response(
            jsonEncode({'code': '42501', 'message': 'denied'}), 403,
            request: request, headers: {'content-type': 'application/json'});
      }
      final rows = offset == 0
          ? [for (var i = 0; i < 200; i++) _capture(i)]
          : [_capture(200)];
      return http.Response(jsonEncode(rows), 200,
          request: request, headers: {'content-type': 'application/json'});
    }));
  });
  tearDown(() async => client.dispose());

  test(
      'report read scopes finalized captures to Manila month and report sites, paginates and skips evidence',
      () async {
    final captures = await SupabaseRecordService.loadReportCaptures(
        month: DateTime(2026, 11), siteCodes: ['S4'], client: client);
    expect(captures, hasLength(201));
    expect(captures.last.id, 'capture-200');
    expect(captures.first.confirmedCount, 1);
    expect(captures.first.detectionBoxes.single.score, .9);
    expect(requests, hasLength(2));
    for (final request in requests) {
      expect(request.method, 'GET');
      expect(request.url.path, '/rest/v1/captures');
      final query = request.url.queryParametersAll;
      expect(query['status'], ['eq.finalized']);
      expect(
          query['captured_at'],
          containsAll(
              ['gte.2026-10-31T16:00:00.000Z', 'lt.2026-11-30T16:00:00.000Z']));
      expect(query['monitoring_areas.code']!.single, contains('S4'));
      expect(query['select']!.single, contains('monitoring_areas!inner'));
      expect(
          query['order']!.single, 'captured_at.asc.nullslast,id.asc.nullslast');
      expect(query['limit'], ['200']);
    }
    expect(requests.last.url.queryParameters['offset'], '200');
  });

  test('no report sites needs no database or image requests', () async {
    final captures = await SupabaseRecordService.loadReportCaptures(
        month: DateTime(2026, 11), siteCodes: [], client: client);
    expect(captures, isEmpty);
    expect(requests, isEmpty);
  });

  test('a later page failure is not returned as a complete report', () async {
    failSecondPage = true;
    await expectLater(
        SupabaseRecordService.loadReportCaptures(
            month: DateTime(2026, 11), siteCodes: ['S4'], client: client),
        throwsA(isA<PostgrestException>()));
    expect(requests, hasLength(2));
  });
}
