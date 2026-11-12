import 'dart:convert';
import 'package:cots_monitor/services/supabase_evidence_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('copy uses Storage server transport with no photo bytes sent', () async {
    var calls = 0;
    final client = SupabaseClient('https://copy.example.invalid', 'fixture-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      calls++;
      expect(request.method, 'POST');
      expect(request.url.path, '/storage/v1/object/copy');
      expect(jsonDecode(request.body), {
        'bucketId': 'detection-evidence',
        'sourceKey': 'owner/detection/variant',
        'destinationKey': 'owner/removal/variant',
        'destinationBucket': 'elimination-evidence',
      });
      return http.Response(
          jsonEncode({'Key': 'elimination-evidence/owner/removal/variant'}),
          200,
          headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    await SupabaseEvidenceGateway(client).copy(
        'detection-evidence',
        'owner/detection/variant',
        'elimination-evidence',
        'owner/removal/variant');
    expect(calls, 1);
  });
}
