import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../models/cots_detection_result.dart';
import 'yolo_image_preprocess.dart';
import 'yolo_postprocess.dart';

/// On-device COTS detector using YOLOv8 / RT-DETR ONNX via flutter_onnxruntime.
class CotsYoloDetector {
  CotsYoloDetector._();

  static final CotsYoloDetector instance = CotsYoloDetector._();

  static const modelAssetPath = 'assets/models/yolov8_best.onnx';

  final _preprocessor = const YoloImagePreprocessor();
  final _postprocessor = const YoloPostprocessor();

  final OnnxRuntime _runtime = OnnxRuntime();
  OrtSession? _session;
  String? _inputName;
  String? _outputName;
  bool _initializing = false;

  Future<void> _ensureSession() async {
    if (_session != null || _initializing) {
      while (_initializing) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return;
    }

    _initializing = true;
    try {
      _session = await _runtime.createSessionFromAsset(modelAssetPath);
      final inputs = await _session!.getInputInfo();
      final outputs = await _session!.getOutputInfo();

      if (inputs.isEmpty || outputs.isEmpty) {
        throw StateError('Model has no inputs/outputs.');
      }

      _inputName = inputs.first['name'] as String? ?? 'images';
      _outputName = outputs.first['name'] as String? ?? 'output0';

      if (kDebugMode) {
        debugPrint('ONNX model loaded: $modelAssetPath');
        debugPrint('ONNX inputs: $inputs');
        debugPrint('ONNX outputs: $outputs');
      }
    } finally {
      _initializing = false;
    }
  }

  Future<CotsDetectionResult> detect(Uint8List imageBytes) async {
    await _ensureSession();
    final session = _session!;
    final inputName = _inputName!;
    final outputName = _outputName!;

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw FormatException('Could not decode image for detection.');
    }
    // Match display orientation so boxes align with the uploaded photo.
    final oriented = img.bakeOrientation(decoded);

    final preprocessed = _preprocessor.preprocess(oriented);
    OrtValue? inputTensor;
    try {
      inputTensor = await OrtValue.fromList(
        preprocessed.tensor,
        [1, 3, _preprocessor.inputSize, _preprocessor.inputSize],
      );

      final outputs = await session.run({inputName: inputTensor});
      final outputTensor = outputs[outputName] ?? outputs.values.first;

      try {
        final flat = await outputTensor.asFlattenedList();
        final shape = List<int>.from(outputTensor.shape);
        if (kDebugMode) {
          debugPrint('YOLO output shape: $shape');
        }
        final boxes = _postprocessor.decode(flat, shape, preprocessed.meta);
        if (kDebugMode) {
          debugPrint('YOLO detections after NMS: ${boxes.length}');
          if (boxes.isNotEmpty) {
            debugPrint(
              'YOLO top score: ${boxes.first.score.toStringAsFixed(3)}',
            );
          }
        }
        return summarize(boxes);
      } finally {
        await outputTensor.dispose();
        for (final value in outputs.values) {
          if (!identical(value, outputTensor)) {
            await value.dispose();
          }
        }
      }
    } finally {
      await inputTensor?.dispose();
    }
  }

  Future<void> dispose() async {
    await _session?.close();
    _session = null;
    _inputName = null;
    _outputName = null;
  }
}
