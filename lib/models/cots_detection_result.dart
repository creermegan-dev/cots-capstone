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

  int get confidencePercent => (score.clamp(0.0, 1.0) * 100).round();

  Map<String, dynamic> toMap() => {
        'x1': x1,
        'y1': y1,
        'x2': x2,
        'y2': y2,
        'score': score,
      };

  factory CotsBoundingBox.fromMap(Map<String, dynamic> map) {
    double read(String key) {
      final v = map[key];
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? 0;
    }

    return CotsBoundingBox(
      x1: read('x1'),
      y1: read('y1'),
      x2: read('x2'),
      y2: read('y2'),
      score: read('score'),
    );
  }

  static List<CotsBoundingBox> listFromDynamic(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map<String, dynamic>) CotsBoundingBox.fromMap(item)
        else if (item is Map) CotsBoundingBox.fromMap(Map<String, dynamic>.from(item)),
    ];
  }
}
