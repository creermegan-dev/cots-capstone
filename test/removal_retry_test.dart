import 'dart:convert';

import 'package:cots_monitor/models/removal_record_model.dart';
import 'package:cots_monitor/services/processed_detection_payload.dart';
import 'package:cots_monitor/services/windows_removal_record_rest_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final quantity in <int?>[2, 0, null]) {
    test('removal retry preserves capture link and reported quantity $quantity',
        () async {
      Map<String, dynamic>? saved;
      var creates = 0;
      final client = MockClient((request) async {
          if (request.method == 'GET') {
          return http.Response(jsonEncode(saved), 200);
          }
        expect(request.url.queryParameters['documentId'], 'new-scan_removal');
        if (saved != null) return http.Response('{}', 409);
        creates++;
        saved = {
          'name':
              'projects/test/databases/(default)/documents/removal_records/new-scan_removal',
          'fields': jsonDecode(request.body)['fields'],
        };
        return http.Response('{}', 200);
      });
      addTearDown(client.close);
      final service = WindowsRemovalRecordRestService(client: client);
      Future<String> submit({int? removed}) => service.createRemovalRecord(
            submissionId: 'new-scan_removal',
            idToken: 'test-token',
            captureId: 'new-scan',
            uid: 'diver',
            submittedBy: 'Diver',
            imageName: 'photo.jpg',
            removedQuantity: removed,
            removalMethod: 'Recorded method',
            notes: '',
            depth: null,
            latitude: null,
            longitude: null,
            dateTaken: null,
            zone: 'Unassigned',
            aiVerifiedCount: 4,
            aiConfidence: .67,
          );
      expect(await submit(removed: quantity), 'new-scan_removal');
      expect(await submit(removed: quantity), 'new-scan_removal');
      expect(creates, 1);
      expect(
          saved!['fields']['removed_quantity'],
          quantity == null
              ? {'nullValue': null}
              : {'integerValue': '$quantity'});
      expect(saved!['fields']['ai_verified_count'], {'integerValue': '4'});
      final model = RemovalRecordModel.fromRestDocument(saved!);
      expect(model.removedQuantity, quantity);
      expect(model.toAdminTableRow(1).removedQuantity, quantity);
      await expectLater(submit(removed: 3), throwsStateError);
      expect(creates, 1);
    });
  }

  test(
      'native removal payload keeps unreported quantity separate from AI count',
      () {
    final payload = ProcessedDetectionPayload.removalFields(
      captureId: 'capture',
      uid: 'diver',
      submittedBy: 'Diver',
      imageName: 'photo.jpg',
      removedQuantity: null,
      removalMethod: 'Recorded method',
      notes: '',
      depth: null,
      latitude: null,
      longitude: null,
      dateTaken: null,
      zone: 'Unassigned',
      aiVerifiedCount: 4,
      aiConfidence: .67,
    );
    expect(payload.containsKey('removed_quantity'), isTrue);
    expect(payload['removed_quantity'], isNull);
    expect(payload['removal_method'], 'Recorded method');
    expect(payload['ai_verified_count'], 4);
  });
}
