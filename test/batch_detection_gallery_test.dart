import 'dart:typed_data';

import 'package:cots_monitor/features/user/widgets/batch_detection_gallery.dart';
import 'package:cots_monitor/models/cots_detection_result.dart';
import 'package:cots_monitor/widgets/cots_detection_image_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  final bytes =
      Uint8List.fromList(img.encodePng(img.Image(width: 200, height: 100)));
  final photos = [
    DetectionPhotoPreview(
        id: 'one',
        name: 'first-photo-with-a-long-filename.png',
        bytes: bytes,
        width: 200,
        height: 100,
        detection: const CotsDetectionResult(count: 2, confidence: .65, boxes: [
          CotsBoundingBox(x1: 10, y1: 20, x2: 60, y2: 70, score: .9),
          CotsBoundingBox(x1: 110, y1: 20, x2: 160, y2: 70, score: .4),
        ])),
    DetectionPhotoPreview(
        id: 'two',
        name: 'second.png',
        bytes: bytes,
        width: 200,
        height: 100,
        detection: const CotsDetectionResult(count: 1, confidence: .85, boxes: [
          CotsBoundingBox(x1: 30, y1: 20, x2: 90, y2: 80, score: .85),
        ])),
    DetectionPhotoPreview(
        id: 'failed',
        name: 'failed.png',
        bytes: bytes,
        width: 200,
        height: 100,
        error: 'Could not analyze this image.'),
  ];

  for (final layout in [(320.0, 1.0), (320.0, 2.0), (960.0, 1.0)]) {
    testWidgets('batch overview, photo selection and back at $layout',
        (tester) async {
      tester.view.physicalSize = Size(layout.$1, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(layout.$2)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
              child: Column(children: [
            BatchDetectionGallery(photos: photos),
            TextFormField(
                key: const ValueKey('removal-quantity'),
                decoration: const InputDecoration(
                    labelText: 'Actual eliminated quantity')),
          ])),
        ))),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('detection-thumbnail-one')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('detection-thumbnail-two')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('detection-thumbnail-failed')),
          findsOneWidget);
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('batch-detection-total')))
              .data,
          '3');
      expect(find.text('Confidence and review status'), findsNothing);
      expect(find.text('Overall confidence: 72%'), findsOneWidget);
      expect(find.byType(CotsDetectionImageOverlay), findsNothing);
      await tester
          .ensureVisible(find.byKey(const ValueKey('removal-quantity')));
      await tester.enterText(
          find.byKey(const ValueKey('removal-quantity')), '7');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester
          .ensureVisible(find.byKey(const ValueKey('detection-thumbnail-one')));
      await tester.tap(find.byKey(const ValueKey('detection-thumbnail-one')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('batch-detection-total')), findsNothing);
      expect(find.byKey(const ValueKey('batch-detection-confidence')),
          findsNothing);
      expect(find.text('2 COTS detected in this photo'), findsOneWidget);
      expect(find.text('Overall confidence: 65%'), findsOneWidget);
      expect(find.text('COTS 1: 90%'), findsNothing);
      expect(find.text('COTS 2: 40%'), findsNothing);
      expect(find.text('Confidence and review status'), findsNothing);
      expect(
          tester
              .widget<CotsDetectionImageOverlay>(
                  find.byType(CotsDetectionImageOverlay))
              .items,
          hasLength(2));
      await tester.ensureVisible(find.byTooltip('Back to all photos'));
      await tester.tap(find.byTooltip('Back to all photos'));
      await tester.pumpAndSettle();
      expect(find.text('Confidence and review status'), findsNothing);
      expect(
          find.byKey(const ValueKey('batch-detection-total')), findsOneWidget);
      expect(find.text('Overall confidence: 72%'), findsOneWidget);
      await tester
          .ensureVisible(find.byKey(const ValueKey('detection-thumbnail-two')));
      await tester.tap(find.byKey(const ValueKey('detection-thumbnail-two')));
      await tester.pumpAndSettle();
      expect(find.text('1 COTS detected in this photo'), findsOneWidget);
      expect(find.text('Overall confidence: 85%'), findsOneWidget);
      expect(find.text('COTS 1: 85%'), findsNothing);
      expect(
          tester
              .widget<CotsDetectionImageOverlay>(
                  find.byType(CotsDetectionImageOverlay))
              .items
              .single
              .confidencePercent,
          85);
      expect(find.text('Requires Expert Validation'), findsNothing);
      expect(
          tester
              .widget<EditableText>(find.descendant(
                  of: find.byKey(const ValueKey('removal-quantity')),
                  matching: find.byType(EditableText)))
              .controller
              .text,
          '7');
      await tester.ensureVisible(find.byTooltip('Back to all photos'));
      await tester.tap(find.byTooltip('Back to all photos'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
          find.byKey(const ValueKey('detection-thumbnail-failed')));
      await tester
          .tap(find.byKey(const ValueKey('detection-thumbnail-failed')));
      await tester.pumpAndSettle();
      expect(find.text('Could not analyze this image.'), findsOneWidget);
      expect(find.byKey(const ValueKey('selected-photo-count')), findsNothing);
      expect(find.byKey(const ValueKey('selected-photo-confidence')),
          findsNothing);
      expect(find.text('Automatically Accepted'), findsNothing);
      expect(tester.takeException(), isNull);
      // Review reuses the same totals without a photo-selection instruction.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BatchDetectionSummary(photos: photos),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Total COTS detected'), findsOneWidget);
      expect(find.text('Overall confidence: 72%'), findsOneWidget);
      expect(find.text('Across 3 uploaded photos'), findsOneWidget);
      expect(find.text('Tap a photo to inspect its detection results.'),
          findsNothing);
      expect(find.byType(InkWell), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
