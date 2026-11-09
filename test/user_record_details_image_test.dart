import 'dart:io';
import 'dart:typed_data';

import 'package:cots_monitor/features/user/user_record_details_page.dart';
import 'package:cots_monitor/models/activity_type.dart';
import 'package:cots_monitor/models/cots_confidence_policy.dart';
import 'package:cots_monitor/models/record_collection.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/widgets/submitted_scan_image.dart';
import 'package:cots_monitor/widgets/cots_detection_image_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

void main() {
  for (final size in [
    (320.0, 1.0),
    (390.0, 1.0),
    (1200.0, 1.0),
    (320.0, 2.0)
  ]) {
    testWidgets('record detail sections remain readable at $size',
        (tester) async {
      tester.view.physicalSize = Size(size.$1, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final record = ScanRecordModel(
          id: 'layout-record',
          uid: 'owner',
          submittedBy: 'Diver with a long name',
          imageName: 'original-photo-with-a-long-filename.jpg',
          imagePath: '',
          activityType: CotsActivityType.detectionOnly,
          aiDetectedCount: 1,
          confidence: .9,
          captureSource: CaptureSource.goProUnderwaterImage,
          zone: 'Site 4 · Balet',
          notes: 'Original field remarks',
          submittedAt: DateTime(2026, 11, 8),
          latitude: 7.15,
          longitude: 125.75,
          removedQuantity: 1,
          averageSizeCm: 23);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(size.$2)),
              child: child!),
          home: UserRecordDetailsPage(record: record, watchSurvey: false)));
      // The page can contain continuously active image/network work. A bounded
      // pump is sufficient after precaching and avoids suite-order timeouts.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Original field remarks'), findsOneWidget);
      expect(find.text('Reported removals'), findsOneWidget);
      expect(find.text('Site 4 · Balet'), findsOneWidget);
      expect(find.text('Status Information'), findsNothing);
      if (size.$1 < 900) {
        expect(tester.getTopLeft(find.text('Detection Image')).dy,
            lessThan(tester.getTopLeft(find.text('Detection Results')).dy));
        expect(
            tester.getTopLeft(find.text('Information')).dy,
            lessThan(
                tester.getTopLeft(find.text('How verification works')).dy));
      }
      expect(tester.takeException(), isNull);
    });
  }
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
        adminCotsDecisions: const [PerCotsAdminDecision.rejected],
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
      // Avoid waiting for unrelated, continuously active page work.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final image =
          tester.widget<SubmittedScanImage>(find.byType(SubmittedScanImage));
      expect(image.recordCollection, collection);
      expect(image.storageObjectPath, record.storageObjectPath);
      expect(
          tester
              .widget<CotsDetectionImageOverlay>(
                  find.byType(CotsDetectionImageOverlay))
              .decisions,
          [PerCotsAdminDecision.rejected]);
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
