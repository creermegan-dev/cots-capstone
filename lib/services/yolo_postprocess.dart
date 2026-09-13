import 'dart:math' as math;



import '../models/cots_detection_result.dart';

import 'yolo_image_preprocess.dart';



/// Parses YOLOv8 ONNX output and applies NMS.

///

/// Ultralytics ONNX exports for this project emit **normalized xywh** (0–1 on the

/// 640×640 letterbox canvas). They must be scaled to input pixels before NMS.

class YoloPostprocessor {

  const YoloPostprocessor({

    this.confThreshold = 0.35,

    this.iouThreshold = 0.45,

    this.maxDetections = 100,

    this.minBoxSidePx = 8,

  });



  final double confThreshold;

  final double iouThreshold;

  final int maxDetections;

  final double minBoxSidePx;



  List<CotsBoundingBox> decode(

    List<dynamic> flatOutput,

    List<int> shape,

    LetterboxMeta meta,

  ) {

    if (shape.length != 3) return const [];

    // RT-DETR: [1, num_queries, 6] with xyxy + confidence + class.
    if (shape[2] == 6 && shape[1] >= 6 && shape[1] <= 1000) {
      return _decodeRtDetr(flatOutput, shape, meta);
    }

    final (channels, anchors, channelMajor) = _resolveLayout(shape);

    if (channels < 5 || anchors <= 0) return const [];



    final normalizedCoords = _usesNormalizedCoords(

      flatOutput,

      channels,

      anchors,

      channelMajor,

    );



    final candidates = <CotsBoundingBox>[];

    for (var i = 0; i < anchors; i++) {

      var cx = _value(flatOutput, channels, anchors, channelMajor, 0, i);

      var cy = _value(flatOutput, channels, anchors, channelMajor, 1, i);

      var w = _value(flatOutput, channels, anchors, channelMajor, 2, i);

      var h = _value(flatOutput, channels, anchors, channelMajor, 3, i);

      final score = _bestScore(flatOutput, channels, anchors, channelMajor, i);



      if (score < confThreshold) continue;



      if (normalizedCoords) {

        final scale = meta.inputSize.toDouble();

        cx *= scale;

        cy *= scale;

        w *= scale;

        h *= scale;

      }



      final x1 = _toSourceX(cx - w / 2, meta);

      final y1 = _toSourceY(cy - h / 2, meta);

      final x2 = _toSourceX(cx + w / 2, meta);

      final y2 = _toSourceY(cy + h / 2, meta);



      if ((x2 - x1) < minBoxSidePx || (y2 - y1) < minBoxSidePx) continue;



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

  List<CotsBoundingBox> _decodeRtDetr(
    List<dynamic> flatOutput,
    List<int> shape,
    LetterboxMeta meta,
  ) {
    final queries = shape[1];
    const cols = 6;
    final scale = meta.inputSize.toDouble();
    final candidates = <CotsBoundingBox>[];

    for (var i = 0; i < queries; i++) {
      final base = i * cols;
      var x1 = (flatOutput[base] as num).toDouble();
      var y1 = (flatOutput[base + 1] as num).toDouble();
      var x2 = (flatOutput[base + 2] as num).toDouble();
      var y2 = (flatOutput[base + 3] as num).toDouble();
      final score = (flatOutput[base + 4] as num).toDouble();

      if (score < confThreshold) continue;

      if (x2 <= 1.5 && y2 <= 1.5) {
        x1 *= scale;
        y1 *= scale;
        x2 *= scale;
        y2 *= scale;
      }

      final sx1 = _toSourceX(x1, meta);
      final sy1 = _toSourceY(y1, meta);
      final sx2 = _toSourceX(x2, meta);
      final sy2 = _toSourceY(y2, meta);

      final left = math.min(sx1, sx2).clamp(0, meta.sourceWidth.toDouble());
      final top = math.min(sy1, sy2).clamp(0, meta.sourceHeight.toDouble());
      final right = math.max(sx1, sx2).clamp(0, meta.sourceWidth.toDouble());
      final bottom = math.max(sy1, sy2).clamp(0, meta.sourceHeight.toDouble());

      if ((right - left) < minBoxSidePx || (bottom - top) < minBoxSidePx) {
        continue;
      }

      candidates.add(
        CotsBoundingBox(
          x1: left.toDouble(),
          y1: top.toDouble(),
          x2: right.toDouble(),
          y2: bottom.toDouble(),
          score: score,
        ),
      );
    }

    return _nms(candidates);
  }

  /// Ultralytics YOLOv8 ONNX emits 0–1 box params; pixel-space exports reach ~640.

  bool _usesNormalizedCoords(

    List<dynamic> flat,

    int channels,

    int anchors,

    bool channelMajor,

  ) {

    var maxCoord = 0.0;

    final sample = math.min(anchors, 512);

    for (var c = 0; c < 4; c++) {

      for (var i = 0; i < sample; i++) {

        final v = _value(flat, channels, anchors, channelMajor, c, i).abs();

        if (v > maxCoord) maxCoord = v;

      }

    }

    return maxCoord <= 2.5;

  }



  /// Supports `[1, 5, 8400]` (channel-major) and `[1, 8400, 5]` (anchor-major).

  (int channels, int anchors, bool channelMajor) _resolveLayout(List<int> shape) {

    final d1 = shape[1];

    final d2 = shape[2];

    if (d1 >= 5 && d1 <= 256 && d2 > d1) {

      return (d1, d2, true);

    }

    if (d2 >= 5 && d2 <= 256 && d1 > d2) {

      return (d2, d1, false);

    }

    return (d1, d2, true);

  }



  double _bestScore(

    List<dynamic> flat,

    int channels,

    int anchors,

    bool channelMajor,

    int anchor,

  ) {

    if (channels == 5) {

      return _value(flat, channels, anchors, channelMajor, 4, anchor);

    }

    var best = 0.0;

    for (var c = 4; c < channels; c++) {

      final score = _value(flat, channels, anchors, channelMajor, c, anchor);

      if (score > best) best = score;

    }

    return best;

  }



  double _value(

    List<dynamic> flat,

    int channels,

    int anchors,

    bool channelMajor,

    int channel,

    int anchor,

  ) {

    final index = channelMajor

        ? channel * anchors + anchor

        : anchor * channels + channel;

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

