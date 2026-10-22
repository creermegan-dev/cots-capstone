import 'dart:typed_data';

import 'package:cots_monitor/models/cots_confidence_policy.dart';
import 'package:cots_monitor/models/cots_detection_result.dart';
import 'package:cots_monitor/widgets/cots_detection_image_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

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
    final box = tester
        .widgetList<Positioned>(find.byType(Positioned))
        .firstWhere((p) => p.left == 50 && p.top == 50);
    expect(box.width, 2); // previously inflated to 24 pixels
    expect(box.height, 3);
    expect(tester.takeException(), isNull);
  });
}
