import 'dart:io';
import 'dart:typed_data';

import 'package:cots_monitor/features/user/user_record_details_page.dart';
import 'package:cots_monitor/models/activity_type.dart';
import 'package:cots_monitor/models/record_collection.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/widgets/submitted_scan_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

void main() {
  testWidgets('record details preserves the photo storage collection',
      (tester) async {
    final directory = Directory.systemTemp.createTempSync('record-photo-test');
    addTearDown(() => directory.deleteSync(recursive: true));
    final bytes =
        Uint8List.fromList(img.encodePng(img.Image(width: 32, height: 32)));
    final photo = File('${directory.path}/photo.png')..writeAsBytesSync(bytes);
    for (final collection in [
      RecordCollection.captures,
      RecordCollection.removalRecords,
      RecordCollection.legacyScanRecords,
    ]) {
      final record = ScanRecordModel(
        id: 'record-$collection',
        uid: 'owner',
        submittedBy: 'Diver',
        imageName: 'photo.png',
        imagePath: photo.path,
        storageObjectPath: 'owner/asset/variant',
        recordCollection: collection,
        activityType: CotsActivityType.detectionOnly,
        aiDetectedCount: 1,
        confidence: .9,
        captureSource: CaptureSource.goProUnderwaterImage,
        zone: 'Test site',
        notes: '',
        submittedAt: DateTime.utc(2026, 11, 5, 12, 6),
        dateTaken: DateTime.utc(2026, 11, 5, 11, 54),
        timeSource: 'exif',
        imageWidth: 32,
        imageHeight: 32,
      );
      await tester.pumpWidget(MaterialApp(
          home: UserRecordDetailsPage(record: record, watchSurvey: false)));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.runAsync(() => precacheImage(
          MemoryImage(bytes), tester.element(find.byType(SubmittedScanImage))));
      await tester.pumpAndSettle();
      final image =
          tester.widget<SubmittedScanImage>(find.byType(SubmittedScanImage));
      expect(image.recordCollection, collection);
      expect(image.storageObjectPath, record.storageObjectPath);
      final format = DateFormat('MMM d, yyyy h:mm a');
      expect(find.text(format.format(record.submittedAt!.toLocal())),
          findsOneWidget);
      expect(find.textContaining(format.format(record.dateTaken!.toLocal())),
          findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Submitted photo unavailable for this record.'),
          findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
