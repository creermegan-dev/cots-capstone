import 'package:cots_monitor/services/supabase_record_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('location source stored with a record', () {
    test('GPS read from the photo is labelled exif', () {
      expect(
        SupabaseRecordService.gpsSourceFor(hasGps: true, gpsFromPhoto: true),
        'exif',
      );
    });

    test('phone fallback location is labelled device_surface', () {
      expect(
        SupabaseRecordService.gpsSourceFor(hasGps: true, gpsFromPhoto: false),
        'device_surface',
      );
    });

    test('no coordinates are labelled unavailable', () {
      expect(
        SupabaseRecordService.gpsSourceFor(hasGps: false, gpsFromPhoto: true),
        'unavailable',
      );
      expect(
        SupabaseRecordService.gpsCapturedAt(
          hasGps: false,
          capturedAt: DateTime.utc(2026, 10, 30),
        ),
        isNull,
      );
    });

    test('submissions queued by older builds keep their previous label', () {
      expect(SupabaseRecordService.gpsSourceFor(hasGps: true), 'exif');
    });

    test('photo GPS keeps the photo time; phone GPS uses submission time', () {
      final taken = DateTime.utc(2026, 10, 1, 8);
      final now = DateTime.utc(2026, 10, 30, 9);
      expect(
        SupabaseRecordService.gpsCapturedAt(
          hasGps: true,
          gpsFromPhoto: true,
          capturedAt: taken,
          now: now,
        ),
        taken.toIso8601String(),
      );
      expect(
        SupabaseRecordService.gpsCapturedAt(
          hasGps: true,
          gpsFromPhoto: false,
          capturedAt: taken,
          now: now,
        ),
        now.toIso8601String(),
      );
    });
  });
}
