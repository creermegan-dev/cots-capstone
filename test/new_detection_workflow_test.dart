import 'package:cots_monitor/features/user/scan_detection_page.dart';
import 'package:cots_monitor/models/activity_type.dart';
import 'package:cots_monitor/models/capture_model.dart';
import 'package:cots_monitor/models/cots_detection_result.dart';
import 'package:cots_monitor/models/removal_record_model.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/services/scan_record_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
        'new encounter upload has no previous-record/activity choice ($scale)',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const ScanDetectionPage(),
      ));
      expect(find.text('New Detection'), findsOneWidget);
      expect(find.text('Detection Only'), findsNothing);
      expect(find.text('Activity Type'), findsNothing);
      expect(find.text('Previous Detection'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink()); // dispose live clock
    });
  }

  test('new encounter is one history row, with per-COTS review and human count',
      () {
    final capture = ScanRecordModel.fromCapture(CaptureModel(
      id: 'new',
      uid: 'diver',
      submittedBy: 'Diver',
      imageName: 'photo.jpg',
      aiDetectedCount: 1,
      confidence: .3,
      captureSource: CaptureSource.goProUnderwaterImage,
      zone: 'Unassigned',
      notes: '',
      submittedAt: DateTime(2026, 10, 22),
      detectionBoxes: const [
        CotsBoundingBox(x1: 1, y1: 1, x2: 50, y2: 50, score: .3)
      ],
      imageWidth: 100,
      imageHeight: 100,
    ));
    ScanRecordModel removal(String id, {int? quantity = 2}) =>
        ScanRecordModel.fromRemovalRecord(
          RemovalRecordModel(
              id: id,
              captureId: 'new',
              uid: 'diver',
              submittedBy: 'Diver',
              imageName: 'photo.jpg',
              removedQuantity: quantity,
              removalMethod: 'Recorded method',
              zone: 'Unassigned',
              notes: '',
              submittedAt: null),
        );
    final merged = ScanRecordRepository.mergeCaptureRemovalRecords(
        [capture], [removal('new_removal'), removal('older-separate-removal')]);
    expect(merged, hasLength(2));
    expect(merged.first.id, 'new');
    expect(merged.first.aiDetectedCount, 1);
    expect(merged.first.removedQuantity, 2);
    expect(merged.first.userStatusLabel, 'Requires Expert Validation');
    expect(merged.first.recordCollection, 'captures');
    final withoutQuantity = ScanRecordRepository.mergeCaptureRemovalRecords(
        [capture], [removal('new_removal', quantity: null)]);
    expect(
        withoutQuantity.single.activityType, CotsActivityType.removalActivity);
    expect(withoutQuantity.single.removedQuantity, isNull);
    expect(withoutQuantity.single.aiDetectedCount, 1);
    expect(merged.last.id, 'older-separate-removal');
    expect(
        ScanRecordRepository.mergeCaptureRemovalRecords(
            [], [removal('new_removal')]),
        hasLength(1));
  });
}
