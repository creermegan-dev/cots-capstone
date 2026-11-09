import 'package:cots_monitor/models/activity_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy defaults never claim a camera brand', () {
    for (final source in [
      '',
      'GoPro Image',
      CaptureSource.goProUnderwaterImage,
      'Unknown Device',
      'camera'
    ]) {
      expect(CaptureSource.displayLabel(source), 'Photo — camera not recorded');
    }
    expect(CaptureSource.goProUnderwaterImage, 'GoPro Underwater Image');
  });
  test('known source labels and per-photo distinctions remain intact', () {
    expect(CaptureSource.displayLabel('Gallery upload'), 'Photo from gallery');
    expect(CaptureSource.displayLabel('Per photo'), 'Per photo');
    expect(CaptureSource.displayLabel('Imported photo'), 'Imported photo');
  });
}
