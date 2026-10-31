import 'dart:io';

import 'package:cots_monitor/services/supabase_record_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline submission identifiers map to stable UUIDs', () {
    final first = SupabaseRecordService.stableUuid(
      'capture',
      'local-submission-123',
    );
    final retry = SupabaseRecordService.stableUuid(
      'capture',
      'local-submission-123',
    );
    final removal = SupabaseRecordService.stableUuid(
      'elimination',
      'local-submission-123',
    );

    expect(first, retry);
    expect(
        first,
        matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        )));
    expect(removal, isNot(first));
  });

  test('monitoring-area migration contains every GIS monitoring area', () {
    final sql = File(
      'supabase/migrations/20261028000100_monitoring_areas.sql',
    ).readAsStringSync();
    expect(
        RegExp(r"^\('[^']+',", multiLine: true).allMatches(sql), hasLength(75));
    expect(sql, contains("'cots-davao-gulf-v1'"));
    expect(sql, contains('on conflict (code) do update'));
  });
}
