import 'dart:math' as math;

import '../models/cots_detection_result.dart';
import 'yolo_image_preprocess.dart';

/// Parses YOLOv8 ONNX output and applies NMS.
class YoloPostprocessor {
  const YoloPostprocessor({
    this.confThreshold = 0.25,
    this.iouThreshold = 0.45,
    this.maxDetections = 300,
  });

  final double confThreshold;
  final double iouThreshold;
  final int maxDetections;

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
      final score = _value(flatOutput, channels, anchors, 4, i);

      if (score < confThreshold) continue;

      final x1 = _toSourceX((cx - w / 2), meta);
      final y1 = _toSourceY((cy - h / 2), meta);
      final x2 = _toSourceX((cx + w / 2), meta);
      final y2 = _toSourceY((cy + h / 2), meta);

      candidates.add(
        CotsBoundingBox(
          x1: x1.clamp(0, meta.sourceWidth.toDouble()),
          y1: y1.clamp(0, meta.sourceHeight.toDouble()),
          x2: x2.clamp(0, meta.sourceWidth.toDouble()),
          y2: y2.clamp(0, meta.sourceHeight.toDouble()),
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
