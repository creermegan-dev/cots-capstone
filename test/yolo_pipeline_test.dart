import 'package:cots_monitor/models/cots_confidence_policy.dart';
import 'package:cots_monitor/services/yolo_image_preprocess.dart';
import 'package:cots_monitor/services/yolo_postprocess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const meta = LetterboxMeta(
  scale: 1,
  padX: 0,
  padY: 160,
  inputSize: 640,
  sourceWidth: 640,
  sourceHeight: 320,
);

List<double> tensor(List<List<double>> rows, {bool transposed = false}) {
  const anchors = 8400;
  final flat = List<double>.filled(anchors * 5, 0);
  for (var i = 0; i < rows.length; i++) {
    for (var c = 0; c < 5; c++) {
      flat[transposed ? i * 5 + c : c * anchors + i] = rows[i][c];
    }
  }
  return flat;
}

void main() {
  test('YOLO26 uses pixel xyxy rows and preserves uncertain candidates', () {
    final boxes = const YoloPostprocessor().decode([
      150.0,
      220.0,
      250.0,
      300.0,
      .9,
      0.0,
      151.0,
      221.0,
      251.0,
      301.0,
      .29,
      0.0,
      300.0,
      220.0,
      350.0,
      270.0,
      .19,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
    ], [
      1,
      4,
      6
    ], meta, endToEnd: true);
    expect(boxes, hasLength(2));
    expect(boxes.first.x1, 150);
    expect(boxes.first.y1, 60);
    expect(boxes.first.y2, 140);
    // Native end-to-end rows must not receive a second NMS pass.
    expect(boxes.last.score, .29);
    expect(CotsConfidencePolicy.bandFromConfidence(boxes.last.score),
        CotsVerificationBand.adminReview);
  });

  test('YOLO26 rejects wrong layouts/classes and clips source boundaries', () {
    const decoder = YoloPostprocessor();
    expect(
        () => decoder.decode(List.filled(5, 0.0), [1, 1, 5], meta,
            endToEnd: true),
        throwsFormatException);
    expect(
        () => decoder
            .decode([10, 200, 30, 250, .9, 1], [1, 1, 6], meta, endToEnd: true),
        throwsFormatException);
    expect(
        () => decoder.decode([10, 200, 30, 250, 1.1, 0], [1, 1, 6], meta,
            endToEnd: true),
        throwsFormatException);
    final boxes = decoder.decode([
      -10,
      150,
      650,
      500,
      .9,
      0,
      20,
      200,
      20,
      250,
      .8,
      0,
    ], [
      1,
      2,
      6
    ], meta, endToEnd: true);
    expect(boxes, hasLength(1));
    expect(boxes.single.x1, 0);
    expect(boxes.single.y1, 0);
    expect(boxes.single.x2, 640);
    expect(boxes.single.y2, 320);
    expect(
        decoder.decode(List.filled(600, 0.0), [1, 100, 6], meta,
            endToEnd: true),
        isEmpty);
  });

  for (final transposed in [false, true]) {
    test('raw YOLO coordinates, review-band scores and NMS ($transposed)', () {
      final boxes = const YoloPostprocessor().decode(
          tensor([
            [200, 260, 100, 80, .9],
            [202, 262, 100, 80, .8], // same object: suppress
            [400, 300, 40, 40, .3], // retain for Expert review
            [500, 300, 40, 40, .19], // below review band
          ], transposed: transposed),
          transposed ? [1, 8400, 5] : [1, 5, 8400],
          meta);
      expect(boxes, hasLength(2));
      expect(boxes.first.x1, 150);
      expect(boxes.first.y1, 60); // remove letterbox padding
      expect(boxes.first.y2, 140);
      expect(CotsConfidencePolicy.bandFromConfidence(boxes.last.score),
          CotsVerificationBand.adminReview);
      expect(summarize(boxes).count, 2);
    });
  }

  test('small pixel boxes are not guessed to be normalized or discarded', () {
    const square = LetterboxMeta(
        scale: 1,
        padX: 0,
        padY: 0,
        inputSize: 640,
        sourceWidth: 640,
        sourceHeight: 640);
    final boxes = const YoloPostprocessor().decode(
        tensor([
          [1, 1, 1, 1, .9]
        ]),
        [1, 5, 8400],
        square);
    expect(boxes.single.x1, .5);
    expect(boxes.single.x2, 1.5);
  });

  test('confidence filter agrees with rounded per-COTS policy', () {
    for (final score in [.1949, .195, .20, .349, .795, .80]) {
      final boxes = const YoloPostprocessor().decode(
          tensor([
            [200, 260, 100, 80, score]
          ]),
          [1, 5, 8400],
          meta);
      expect(boxes.isNotEmpty,
          CotsConfidencePolicy.percentFromConfidence(score) >= 20);
    }
  });

  test('invalid output fails instead of reporting a successful empty scan', () {
    const decoder = YoloPostprocessor();
    expect(() => decoder.decode([], [1, 5, 8400], meta), throwsFormatException);
    expect(() => decoder.decode([0.0], [1], meta), throwsFormatException);
    expect(() => decoder.decode(List.filled(7 * 20, 0.0), [1, 7, 20], meta),
        throwsFormatException);
    expect(
        () => decoder.decode(
            tensor([
              [200, 260, 100, 80, double.nan]
            ]),
            [1, 5, 8400],
            meta),
        throwsFormatException);
    expect(decoder.decode(tensor([]), [1, 5, 8400], meta), isEmpty);
  });

  test('letterbox uses RGB normalized planar values and grey padding', () {
    final source = img.Image(width: 2, height: 1);
    img.fill(source, color: img.ColorRgb8(255, 0, 0));
    final processed =
        const YoloImagePreprocessor(inputSize: 4).preprocess(source);
    expect(processed.meta.padY, 1);
    expect(processed.meta.scale, 2);
    expect(processed.tensor[0], closeTo(114 / 255, 1e-6));
    expect(processed.tensor[4], 1); // red plane, first image row
    expect(processed.tensor[16 + 4], 0); // green plane
    expect(processed.tensor[32 + 4], 0); // blue plane
  });
}
