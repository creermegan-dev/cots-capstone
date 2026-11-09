import 'package:flutter_test/flutter_test.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/features/admin/screens/admin_record_details_screen.dart';

void main() {
  ScanRecordModel record(DateTime submitted, DateTime taken,
          {String source = 'exif'}) =>
      ScanRecordModel(
        id: 'time-test',
        uid: 'diver',
        submittedBy: 'Diver',
        imageName: 'photo.jpg',
        imagePath: '',
        activityType: 'Detection Only',
        aiDetectedCount: 1,
        confidence: .9,
        captureSource: 'Gallery',
        zone: 'Balet',
        notes: '',
        submittedAt: submitted,
        dateTaken: taken,
        timeSource: source,
      );

  test('staff record and detail show Manila time without changing timestamps',
      () {
    final submitted = DateTime.parse('2026-11-08T02:49:00Z');
    final taken = DateTime.parse('2026-11-07T17:30:00Z');
    final model = record(submitted, taken);
    final row = model.toAdminTableRow(1);
    final detail = AdminRecordDetailsData.fromTableRow(row);
    expect(row.dateUploaded, 'Nov 8, 2026 10:49 AM');
    expect(row.dateCaptured, 'Nov 8, 2026 1:30 AM');
    expect(detail.submittedTime, '10:49 AM');
    expect(model.submittedAt, submitted);
    expect(model.dateTaken, taken);
  });

  test('explicit timezone offset is not added twice', () {
    final time = DateTime.parse('2026-11-08T10:49:00+08:00');
    expect(record(time, time).toAdminTableRow(1).dateUploaded,
        'Nov 8, 2026 10:49 AM');
  });

  test('manual date-only capture retains its calendar date', () {
    final time = DateTime.utc(2026, 11, 8, 20);
    expect(record(time, time, source: 'manual').toAdminTableRow(1).dateCaptured,
        'Nov 8, 2026');
  });
}
