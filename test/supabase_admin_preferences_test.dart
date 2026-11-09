import 'dart:convert';

import 'package:cots_monitor/models/admin_preferences.dart';
import 'package:cots_monitor/services/admin_preferences_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late AdminPreferencesRepository repository;
  late List<http.Request> requests;
  Map<String, dynamic>? stored;
  var fail = false;

  setUp(() {
    requests = [];
    stored = null;
    fail = false;
    client = SupabaseClient(
      'https://preferences.example.invalid',
      'fixture-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (fail) {
          return http.Response(
              jsonEncode({'code': '42501', 'message': 'Access denied'}), 403,
              request: request, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'POST') {
          stored = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
          return http.Response('', 201, request: request);
        }
        return http.Response(jsonEncode(stored == null ? [] : [stored]), 200,
            request: request, headers: {'content-type': 'application/json'});
      }),
    );
    repository = AdminPreferencesRepository(supabaseClient: client);
  });
  tearDown(() async => client.dispose());

  test('missing Supabase preferences use defaults without a Firebase read',
      () async {
    final result = await repository.load('admin-1');
    expect(result.uid, 'admin-1');
    expect(result.weeklyReports, isFalse);
    expect(requests.single.url.path, '/rest/v1/admin_preferences');
    expect(requests.single.url.queryParameters['uid'], 'eq.admin-1');
  });

  test('save and reload all switches through Supabase upsert', () async {
    const preferences = AdminPreferences(
      uid: 'admin-1',
      emailNotifications: false,
      highRiskAlerts: false,
      systemUpdates: false,
      weeklyReports: true,
      twoFactorAuth: true,
      loginAlerts: false,
      sessionTimeout: false,
    );
    await repository.save(preferences);
    expect(requests.single.method, 'POST');
    expect(requests.single.url.queryParameters['on_conflict'], 'uid');
    expect(stored, preferences.toMap());
    expect((await repository.load('admin-1')).toMap(), preferences.toMap());
  });

  test('access failures propagate instead of falling back or reporting success',
      () async {
    fail = true;
    await expectLater(
        repository.load('admin-1'), throwsA(isA<PostgrestException>()));
    await expectLater(repository.save(const AdminPreferences(uid: 'admin-1')),
        throwsA(isA<PostgrestException>()));
    expect(requests, hasLength(2));
  });
}
