import 'dart:typed_data';
import 'dart:async';

import 'package:cots_monitor/models/cots_confidence_policy.dart';
import 'package:cots_monitor/models/cots_detection_result.dart';
import 'package:cots_monitor/widgets/cots_detection_image_overlay.dart';
import 'package:cots_monitor/widgets/cots_loading_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('small detection boxes keep their true scaled size',
      (tester) async {
    final image =
        Uint8List.fromList(img.encodePng(img.Image(width: 640, height: 640)));
    final items = CotsConfidencePolicy.buildDetectionItems(
        count: 1,
        averagePercent: 90,
        imageWidth: 640,
        imageHeight: 640,
        boxes: const [
          CotsBoundingBox(x1: 100, y1: 100, x2: 104, y2: 106, score: .9)
        ]);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
          width: 320,
          child: CotsDetectionImageOverlay(
            imageWidth: 640,
            imageHeight: 640,
            items: items,
            imageBytes: image,
          )),
    ))));
    await tester.runAsync(() => precacheImage(MemoryImage(image),
        tester.element(find.byType(CotsDetectionImageOverlay))));
    await tester.pumpAndSettle();
    final box = tester
        .widgetList<Positioned>(find.byType(Positioned))
        .firstWhere((p) => p.left == 50 && p.top == 50);
    expect(box.width, 2); // previously inflated to 24 pixels
    expect(box.height, 3);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CotsLoadingSkeleton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed photo hides boxes and retry restores image and boxes',
      (tester) async {
    final bytes =
        Uint8List.fromList(img.encodePng(img.Image(width: 32, height: 32)));
    final items = CotsConfidencePolicy.buildDetectionItems(
        count: 1,
        averagePercent: 90,
        imageWidth: 32,
        imageHeight: 32,
        boxes: const [
          CotsBoundingBox(x1: 1, y1: 1, x2: 20, y2: 20, score: .9)
        ]);
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 320,
      child: CotsDetectionImageOverlay(
          imageWidth: 32,
          imageHeight: 32,
          items: items,
          loadImage: () async {
            if (attempts++ == 0) {
              throw const StorageException('private diagnostic',
                  statusCode: '403');
            }
            return bytes;
          }),
    ))));
    await tester.pumpAndSettle();
    expect(find.byType(Positioned), findsNothing);
    expect(find.textContaining('Photo access was denied.'), findsOneWidget);
    expect(find.textContaining('private diagnostic'), findsNothing);
    await tester.tap(find.text('Retry photo'));
    await tester.runAsync(() => precacheImage(MemoryImage(bytes),
        tester.element(find.byType(CotsDetectionImageOverlay))));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Positioned &&
            widget.width != null &&
            widget.height != null),
        findsOneWidget);
    expect(find.text('Retry photo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading photo never displays detection boxes', (tester) async {
    final pending = Completer<Uint8List?>();
    final items = CotsConfidencePolicy.buildDetectionItems(
        count: 1,
        averagePercent: 90,
        imageWidth: 32,
        imageHeight: 32,
        boxes: const [
          CotsBoundingBox(x1: 1, y1: 1, x2: 20, y2: 20, score: .9)
        ]);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 320,
      child: CotsDetectionImageOverlay(
          imageWidth: 32,
          imageHeight: 32,
          items: items,
          loadImage: () => pending.future),
    ))));
    await tester.pump();
    expect(find.byType(Positioned), findsNothing);
    pending.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Retry photo'), findsOneWidget);
    expect(find.byType(Positioned), findsNothing);
  });

  testWidgets('corrupt image bytes do not display detection boxes',
      (tester) async {
    final items = CotsConfidencePolicy.buildDetectionItems(
        count: 1,
        averagePercent: 90,
        imageWidth: 32,
        imageHeight: 32,
        boxes: const [
          CotsBoundingBox(x1: 1, y1: 1, x2: 20, y2: 20, score: .9)
        ]);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 320,
      child: CotsDetectionImageOverlay(
          imageWidth: 32,
          imageHeight: 32,
          items: items,
          imageBytes: Uint8List.fromList([1, 2, 3])),
    ))));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be opened'), findsOneWidget);
    expect(find.byType(Positioned), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
