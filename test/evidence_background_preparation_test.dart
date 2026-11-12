import 'dart:async';
import 'dart:typed_data';

import 'package:cots_monitor/services/supabase_evidence_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('background preparation preserves exact JPEG bytes and provenance',
      () async {
    final image = img.Image(width: 48, height: 32)
      ..setPixelRgb(4, 6, 255, 100, 25);
    final original = Uint8List.fromList(img.encodePng(image));
    final expected = EvidenceImagePayload.prepare(
        originalBytes: original, originalName: 'original.png');
    final actual = await EvidenceImagePayload.prepareAsync(
        originalBytes: original, originalName: 'original.png');
    expect(actual.bytes, expected.bytes);
    expect(actual.toMetadata(), expected.toMetadata());
    expect(actual.width, 48);
    expect(actual.height, 32);
  });

  test('event loop stays responsive while preparing a larger photo', () async {
    final original =
        Uint8List.fromList(img.encodePng(img.Image(width: 1600, height: 1200)));
    var heartbeats = 0;
    final timer =
        Timer.periodic(const Duration(milliseconds: 1), (_) => heartbeats++);
    try {
      final prepared = await EvidenceImagePayload.prepareAsync(
          originalBytes: original, originalName: 'field-photo.png');
      expect(heartbeats, greaterThan(1));
      expect(prepared.width, 1600);
      expect(prepared.height, 1200);
    } finally {
      timer.cancel();
    }
  });

  test('invalid photo returns an error from the worker', () async {
    await expectLater(
        EvidenceImagePayload.prepareAsync(
            originalBytes: Uint8List(64), originalName: 'bad.jpg'),
        throwsFormatException);
  });
}
