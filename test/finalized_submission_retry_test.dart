import 'dart:convert';

import 'package:cots_monitor/services/supabase_evidence_service.dart';
import 'package:cots_monitor/services/supabase_record_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> item(int index) => {
      'id': 'item-$index',
      'capture_id': 'capture',
      'item_index': index,
      'confidence': .91,
      'x1': 10.0,
      'y1': 20.0,
      'x2': 100.0,
      'y2': 120.0,
    };

SupabaseClient clientFor(
        Future<http.Response> Function(http.Request) handler) =>
    SupabaseClient('https://retry.example.invalid', 'fixture-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      final response = await handler(request);
      return http.Response.bytes(response.bodyBytes, response.statusCode,
          headers: response.headers, request: request);
    }));

http.Response rows(Object? value) => http.Response(jsonEncode(value), 200,
    headers: {'content-type': 'application/json'});

http.Response frozen() => http.Response(
    jsonEncode(
        {'code': '23514', 'message': 'Invalid source box or frozen capture'}),
    400,
    headers: {'content-type': 'application/json'});

void main() {
  test('finalized capture reuses matching boxes without any INSERT', () async {
    var writes = 0;
    final client = clientFor((request) async {
      if (request.method == 'GET') return rows([item(0)]);
      writes++;
      return frozen();
    });
    addTearDown(client.dispose);
    await SupabaseRecordService.ensureDetectionItems(
        client: client, captureId: 'capture', expected: [item(0)]);
    expect(writes, 0);
  });

  test('interrupted pending capture inserts only missing boxes', () async {
    final inserted = <dynamic>[];
    final client = clientFor((request) async {
      if (request.method == 'GET') return rows([item(0)]);
      inserted.addAll(jsonDecode(request.body) as List);
      return http.Response('', 201);
    });
    addTearDown(client.dispose);
    await SupabaseRecordService.ensureDetectionItems(
        client: client, captureId: 'capture', expected: [item(0), item(1)]);
    expect(inserted, [item(1)]);
  });

  for (final field in ['confidence', 'x1', 'item_index', 'id']) {
    test('same-count retry with changed $field is refused without writes',
        () async {
      var writes = 0;
      final saved = {...item(0), field: field == 'id' ? 'other-item' : 123};
      final client = clientFor((request) async {
        if (request.method == 'GET') return rows([saved]);
        writes++;
        return http.Response('', 201);
      });
      addTearDown(client.dispose);
      await expectLater(
          SupabaseRecordService.ensureDetectionItems(
              client: client, captureId: 'capture', expected: [item(0)]),
          throwsStateError);
      expect(writes, 0);
    });
  }

  test('finalization race resumes only when all saved boxes match', () async {
    var completed = false;
    final client = clientFor((request) async {
      if (request.method == 'GET') return rows(completed ? [item(0)] : []);
      completed = true;
      return frozen();
    });
    addTearDown(client.dispose);
    await SupabaseRecordService.ensureDetectionItems(
        client: client, captureId: 'capture', expected: [item(0)]);
  });

  test('frozen capture without matching saved boxes remains an error',
      () async {
    final client = clientFor(
        (request) async => request.method == 'GET' ? rows([]) : frozen());
    addTearDown(client.dispose);
    await expectLater(
        SupabaseRecordService.ensureDetectionItems(
            client: client, captureId: 'capture', expected: [item(0)]),
        throwsA(isA<PostgrestException>()));
  });

  for (final target in ['capture', 'elimination', 'survey']) {
    test('existing $target evidence link is reused without relinking',
        () async {
      var writes = 0;
      final client = clientFor((request) async {
        if (request.method == 'GET') {
          expect(request.url.queryParameters['variant_id'], 'eq.variant');
          expect(request.url.queryParameters['${target}_id'], 'eq.target');
          return rows({'variant_id': 'variant'});
        }
        writes++;
        return frozen();
      });
      addTearDown(client.dispose);
      await SupabaseEvidenceGateway(client).link(target, 'target', 'variant');
      expect(writes, 0);
    });
  }

  test('missing removal evidence link is created exactly once', () async {
    var linked = false;
    var writes = 0;
    final client = clientFor((request) async {
      if (request.method == 'GET') {
        return rows(linked ? {'variant_id': 'variant'} : null);
      }
      expect(request.url.path, '/rest/v1/rpc/link_evidence');
      linked = true;
      writes++;
      return http.Response('', 204);
    });
    addTearDown(client.dispose);
    final gateway = SupabaseEvidenceGateway(client);
    await gateway.link('elimination', 'target', 'variant');
    await gateway.link('elimination', 'target', 'variant');
    expect(writes, 1);
  });

  test('a lost link response recovers from the exact stored link', () async {
    var linked = false;
    final client = clientFor((request) async {
      if (request.method == 'GET') {
        return rows(linked ? {'variant_id': 'variant'} : null);
      }
      linked = true;
      return frozen();
    });
    addTearDown(client.dispose);
    await SupabaseEvidenceGateway(client)
        .link('elimination', 'target', 'variant');
  });
  test('failed evidence link stays an error when no exact link exists',
      () async {
    final client = clientFor(
        (request) async => request.method == 'GET' ? rows(null) : frozen());
    addTearDown(client.dispose);
    await expectLater(
        SupabaseEvidenceGateway(client)
            .link('elimination', 'target', 'variant'),
        throwsA(isA<PostgrestException>()));
  });
}
