/// Exact user-supplied checkpoints exported for on-device selection.
enum DetectionModel {
  yolo8(
      'yolo8',
      'YOLOv8',
      'assets/models/trained_yolo8.onnx',
      'adef20fa2bd64353114c695875f08fc46679fb6de9d3e396ec7038d1e5568ce2',
      false),
  yolo11(
      'yolo11',
      'YOLO11',
      'assets/models/trained_yolo11.onnx',
      '30075f81627f94da58289044b80fcefa8879d3d2acae3681556ccbd63f02736c',
      false),
  yolo26('yolo26', 'YOLO26', 'assets/models/trained_yolo26.onnx',
      '19ad713742cfbc7263df75173fe3d0e5f1153b9fcd196629e852906927877d39', true);

  const DetectionModel(
      this.id, this.label, this.assetPath, this.sha256, this.endToEnd);
  final String id, label, assetPath, sha256;
  final bool endToEnd;
}

/// Display only stored attribution; never infer it from the active model.
String storedDetectionModelLabel(String? name) {
  final value = name?.trim() ?? '';
  if (value.isEmpty) return 'Model not recorded';
  for (final model in DetectionModel.values) {
    if (value.toLowerCase() == model.id ||
        value.toLowerCase() == model.label.toLowerCase()) {
      return model.label;
    }
  }
  return value;
}
