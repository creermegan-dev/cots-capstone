import 'dart:convert';

import 'package:cots_monitor/models/cots_detection_result.dart';
import 'package:cots_monitor/services/windows_capture_rest_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Windows capture retry reuses its document and checks saved identity',
      () async {
    Map<String, dynamic>? saved;
    var writes = 0;
    var creates = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') return http.Response(jsonEncode(saved), 200);
      expect(request.url.queryParameters['documentId'], 'stable-image');
      writes++;
      if (saved != null) return http.Response('{}', 409);
      creates++;
      saved = {
        'name':
            'projects/test/databases/(default)/documents/captures/stable-image',
        'fields': jsonDecode(request.body)['fields'],
      };
      return http.Response('{}', 200);
    });
    addTearDown(client.close);
    final service = WindowsCaptureRestService(client: client);
    expect(await _submit(service), 'stable-image');
    expect(await _submit(service), 'stable-image');
    expect(writes, 2);
    expect(creates, 1);
    final fields = saved!['fields'] as Map<String, dynamic>;
    expect(fields['monitoring_area_id'], {'stringValue': 'reef-1'});
    expect(fields['follow_up_survey_id'], {'stringValue': 'visit-1'});
    expect(fields['follow_up_year'], {'integerValue': '2026'});
    expect(fields['follow_up_month'], {'integerValue': '10'});
    final gps = fields['gps']['mapValue']['fields'];
    expect(gps['latitude'], {'nullValue': null});
    expect(gps['longitude'], {'nullValue': null});
    await expectLater(
        _submit(service, date: DateTime(2026, 11, 1)), throwsStateError);
    fields['uid'] = {'stringValue': 'another-diver'};
    await expectLater(_submit(service), throwsStateError);
    expect(creates, 1);
  });
}

Future<String> _submit(WindowsCaptureRestService service, {DateTime? date}) =>
    service.createCapture(
      idToken: 'test-token',
      uid: 'diver-1',
      submittedBy: 'Diver One',
      imageName: 'reef.jpg',
      imageWidth: 640,
      imageHeight: 480,
      detection: const CotsDetectionResult(count: 1, confidence: .9, boxes: [
        CotsBoundingBox(x1: 10, y1: 10, x2: 50, y2: 50, score: .9),
      ]),
      latitude: null,
      longitude: null,
      dateTaken: null,
      notes: '',
      depth: null,
      zone: 'A-01',
      monitoringAreaId: 'reef-1',
      followUpSurveyId: 'visit-1',
      followUpSurveyDate: date ?? DateTime(2026, 10, 1),
      submissionId: 'stable-image',
    );
