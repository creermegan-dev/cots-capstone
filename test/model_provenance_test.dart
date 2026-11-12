import 'package:cots_monitor/models/capture_model.dart';
import 'package:cots_monitor/services/cots_yolo_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stored model identity is read without using the current detector', () {
    final capture = CaptureModel.fromRestFields({
      'model_name': {'stringValue': 'yolo8'},
      'model_sha256': {'stringValue': 'original-version'},
    }, id: 'photo');
    expect(capture.modelName, 'yolo8');
    expect(capture.modelSha256, 'original-version');
  });

  test('historical records without model identity remain unknown', () {
    final capture = CaptureModel.fromRestFields({}, id: 'old-photo');
    expect(capture.modelName, isEmpty);
    expect(capture.modelSha256, isEmpty);
  });

  test('active model version is a complete SHA-256 identifier', () {
    expect(CotsYoloDetector.modelSha256, matches(RegExp(r'^[0-9a-f]{64}$')));
  });
}
