import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../models/cots_detection_result.dart';
import 'yolo_image_preprocess.dart';
import 'yolo_postprocess.dart';

/// On-device COTS detector using YOLO26s, with a build-time YOLO11 fallback.
class CotsYoloDetector {
  CotsYoloDetector._();

  static final CotsYoloDetector instance = CotsYoloDetector._();

  static const modelName =
      String.fromEnvironment('COTS_MODEL', defaultValue: 'yolo26');
  static const _usesYolo11 = modelName == 'yolo11';
  static const modelAssetPath = _usesYolo11
      ? 'assets/models/yolov8_best.onnx'
      : 'assets/models/yolo26_best.onnx';

  final _preprocessor = const YoloImagePreprocessor();
  final _postprocessor = const YoloPostprocessor();

  final OnnxRuntime _runtime = OnnxRuntime();
  OrtSession? _session;
  String? _inputName;
  String? _outputName;
  Future<void>? _initialization;

  Future<void> _ensureSession() async {
    if (_session != null) return;
    final pending = _initialization ??= _loadSession();
    try {
      await pending;
    } finally {
      if (identical(_initialization, pending)) _initialization = null;
    }
  }

  Future<void> _loadSession() async {
    if (modelName != 'yolo26' && modelName != 'yolo11') {
      throw ArgumentError('COTS_MODEL must be yolo26 or yolo11.');
    }
    final session = await _runtime.createSessionFromAsset(modelAssetPath);
    try {
      final inputs = await session.getInputInfo();
      final outputs = await session.getOutputInfo();

      if (inputs.isEmpty || outputs.isEmpty) {
        throw StateError('Model has no inputs/outputs.');
      }

      _session = session;
      _inputName = inputs.first['name'] as String? ?? 'images';
      _outputName = outputs.first['name'] as String? ?? 'output0';

      if (kDebugMode) {
        debugPrint('ONNX model loaded: $modelAssetPath');
        debugPrint('ONNX inputs: $inputs');
        debugPrint('ONNX outputs: $outputs');
      }
    } catch (_) {
      await session.close();
      _session = null;
      rethrow;
    }
  }

  Future<CotsDetectionResult> detect(Uint8List imageBytes) async {
    await _ensureSession();
    final session = _session!;
    final inputName = _inputName!;
    final outputName = _outputName!;

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw const FormatException('Could not decode image for detection.');
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
      final outputTensor = outputs[outputName];
      if (outputTensor == null) {
        for (final value in outputs.values) {
          await value.dispose();
        }
        throw StateError('$modelName did not return its expected output.');
      }

      try {
        final flat = await outputTensor.asFlattenedList();
        final shape = List<int>.from(outputTensor.shape);
        if (kDebugMode) {
          debugPrint('YOLO output shape: $shape');
        }
        if (shape.length != 3 ||
            shape[0] != 1 ||
            shape[1] != (_usesYolo11 ? 5 : 100) ||
            shape[2] != (_usesYolo11 ? 8400 : 6)) {
          throw FormatException(
              'Unexpected bundled $modelName output shape: $shape.');
        }
        final boxes = _postprocessor.decode(flat, shape, preprocessed.meta,
            endToEnd: !_usesYolo11);
        if (kDebugMode) {
          debugPrint('$modelName detections after processing: ${boxes.length}');
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
