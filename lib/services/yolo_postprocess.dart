import 'dart:math' as math;

import '../models/cots_detection_result.dart';
import 'yolo_image_preprocess.dart';

/// Parses YOLOv8 ONNX output and applies NMS.
class YoloPostprocessor {
  const YoloPostprocessor({
    // Stricter defaults reduce false positives for single-COTS images.
    this.confThreshold = 0.55,
    this.iouThreshold = 0.35,
    this.maxDetections = 25,
    this.minBoxAreaRatio = 0.00025,
  });

  final double confThreshold;
  final double iouThreshold;
  final int maxDetections;
  final double minBoxAreaRatio;

  List<CotsBoundingBox> decode(
    List<dynamic> flatOutput,
    List<int> shape,
    LetterboxMeta meta,
  ) {
    if (shape.length != 3) return const [];

    final channels = shape[1];
    final anchors = shape[2];
    if (channels < 5 || anchors <= 0) return const [];

    final candidates = <CotsBoundingBox>[];
    for (var i = 0; i < anchors; i++) {
      final cx = _value(flatOutput, channels, anchors, 0, i);
      final cy = _value(flatOutput, channels, anchors, 1, i);
      final w = _value(flatOutput, channels, anchors, 2, i);
      final h = _value(flatOutput, channels, anchors, 3, i);
      final score = _score(flatOutput, channels, anchors, i);

      if (score < confThreshold) continue;

      final x1 = _toSourceX((cx - w / 2), meta);
      final y1 = _toSourceY((cy - h / 2), meta);
      final x2 = _toSourceX((cx + w / 2), meta);
      final y2 = _toSourceY((cy + h / 2), meta);

      final clampedX1 = x1.clamp(0.0, meta.sourceWidth.toDouble()).toDouble();
      final clampedY1 = y1.clamp(0.0, meta.sourceHeight.toDouble()).toDouble();
      final clampedX2 = x2.clamp(0.0, meta.sourceWidth.toDouble()).toDouble();
      final clampedY2 = y2.clamp(0.0, meta.sourceHeight.toDouble()).toDouble();

      final boxW = (clampedX2 - clampedX1).abs();
      final boxH = (clampedY2 - clampedY1).abs();
      final sourceArea = (meta.sourceWidth * meta.sourceHeight).toDouble();
      final boxAreaRatio = sourceArea <= 0 ? 0.0 : (boxW * boxH) / sourceArea;
      if (boxAreaRatio < minBoxAreaRatio) continue;

      candidates.add(
        CotsBoundingBox(
          x1: clampedX1,
          y1: clampedY1,
          x2: clampedX2,
          y2: clampedY2,
          score: score,
        ),
      );
    }

    return _nms(candidates);
  }

  double _value(
    List<dynamic> flat,
    int channels,
    int anchors,
    int channel,
    int anchor,
  ) {
    final index = channel * anchors + anchor;
    return (flat[index] as num).toDouble();
  }

  double _score(
    List<dynamic> flat,
    int channels,
    int anchors,
    int anchor,
  ) {
    // YOLOv8 exports are typically [x, y, w, h, class0, class1, ...] (no obj).
    if (channels == 5) {
      return _value(flat, channels, anchors, 4, anchor);
    }

    // Some exports include objectness at channel 4 and class logits after that.
    if (channels > 5) {
      final objectness = _value(flat, channels, anchors, 4, anchor);
      var bestClass = 0.0;
      for (var ch = 5; ch < channels; ch++) {
        final cls = _value(flat, channels, anchors, ch, anchor);
        if (cls > bestClass) bestClass = cls;
      }
      return objectness * bestClass;
    }

    return 0.0;
  }

  double _toSourceX(double x, LetterboxMeta meta) => (x - meta.padX) / meta.scale;
  double _toSourceY(double y, LetterboxMeta meta) => (y - meta.padY) / meta.scale;

  List<CotsBoundingBox> _nms(List<CotsBoundingBox> boxes) {
    boxes.sort((a, b) => b.score.compareTo(a.score));
    final kept = <CotsBoundingBox>[];

    for (final box in boxes) {
      var suppressed = false;
      for (final selected in kept) {
        if (_iou(box, selected) > iouThreshold) {
          suppressed = true;
          break;
        }
      }
      if (!suppressed) {
        kept.add(box);
        if (kept.length >= maxDetections) break;
      }
    }
    return kept;
  }

  double _iou(CotsBoundingBox a, CotsBoundingBox b) {
    final interX1 = math.max(a.x1, b.x1);
    final interY1 = math.max(a.y1, b.y1);
    final interX2 = math.min(a.x2, b.x2);
    final interY2 = math.min(a.y2, b.y2);

    final interW = math.max(0, interX2 - interX1);
    final interH = math.max(0, interY2 - interY1);
    final interArea = interW * interH;

    final areaA = math.max(0, a.x2 - a.x1) * math.max(0, a.y2 - a.y1);
    final areaB = math.max(0, b.x2 - b.x1) * math.max(0, b.y2 - b.y1);
    final union = areaA + areaB - interArea;
    if (union <= 0) return 0;
    return interArea / union;
  }
}

CotsDetectionResult summarize(List<CotsBoundingBox> boxes) {
  if (boxes.isEmpty) {
    return const CotsDetectionResult(count: 0, confidence: 0, boxes: []);
  }
  final avg = boxes.map((b) => b.score).reduce((a, b) => a + b) / boxes.length;
  return CotsDetectionResult(count: boxes.length, confidence: avg, boxes: boxes);
}
