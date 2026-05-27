/// Result of on-device YOLOv8 COTS detection.
class CotsDetectionResult {
  const CotsDetectionResult({
    required this.count,
    required this.confidence,
    required this.boxes,
  });

  /// Number of COTS instances after NMS.
  final int count;

  /// Mean confidence of kept detections (0–1).
  final double confidence;

  /// Bounding boxes in original image pixel coordinates.
  final List<CotsBoundingBox> boxes;
}

class CotsBoundingBox {
  const CotsBoundingBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.score,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double score;
}
