import 'dart:math' as math;

import '../models/cots_detection_result.dart';

/// Heuristic size estimates when a measurement reference is visible in-frame.
class CotsSizeEstimate {
  const CotsSizeEstimate({
    required this.perCotsCm,
    required this.averageCm,
    required this.minimumCm,
    required this.maximumCm,
    required this.confidenceScore,
  });

  final List<double> perCotsCm;
  final double averageCm;
  final double minimumCm;
  final double maximumCm;
  final double confidenceScore;
}

abstract final class CotsSizeEstimator {
  /// Estimates COTS length (cm) from bounding-box scale vs. image dimensions.
  ///
  /// Assumes a ~30 cm reference object spans ~18% of image width when visible.
  static CotsSizeEstimate? estimate({
    required List<CotsBoundingBox> boxes,
    required int imageWidth,
    required int imageHeight,
  }) {
    if (boxes.isEmpty || imageWidth <= 0 || imageHeight <= 0) return null;

    const referenceWidthCm = 30.0;
    const referenceFractionOfWidth = 0.18;
    final pixelsPerCm =
        (imageWidth * referenceFractionOfWidth) / referenceWidthCm;

    final sizes = <double>[];
    for (final box in boxes) {
      final w = (box.x2 - box.x1).abs();
      final h = (box.y2 - box.y1).abs();
      final longest = math.max(w, h);
      final cm = (longest / pixelsPerCm).clamp(12.0, 65.0);
      sizes.add(double.parse(cm.toStringAsFixed(1)));
    }

    sizes.sort();
    final avg = sizes.reduce((a, b) => a + b) / sizes.length;
    final meanScore =
        boxes.map((b) => b.score).reduce((a, b) => a + b) / boxes.length;

    return CotsSizeEstimate(
      perCotsCm: sizes,
      averageCm: double.parse(avg.toStringAsFixed(1)),
      minimumCm: sizes.first,
      maximumCm: sizes.last,
      confidenceScore: double.parse(meanScore.toStringAsFixed(2)),
    );
  }
}
