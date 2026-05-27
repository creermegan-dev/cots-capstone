import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../models/cots_detection_result.dart';
import 'cots_logger.dart';
import 'yolo_image_preprocess.dart';
import 'yolo_postprocess.dart';

/// On-device COTS detector using YOLOv8 ONNX via flutter_onnxruntime.
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
      if (kIsWeb) {
        throw UnsupportedError('ONNX detection is only supported on mobile builds.');
      }

      _session = await _runtime.createSessionFromAsset(modelAssetPath);
      final inputs = await _session!.getInputInfo();
      final outputs = await _session!.getOutputInfo();

      if (inputs.isEmpty || outputs.isEmpty) {
        throw StateError('Model has no inputs/outputs.');
      }

      _inputName = inputs.first['name'] as String? ?? 'images';
      _outputName = outputs.first['name'] as String? ?? 'output0';
    } finally {
      _initializing = false;
    }
  }

  Future<CotsDetectionResult> detect(Uint8List imageBytes) async {
    CotsLogger.info('Starting COTS YOLO detection pipeline...');
    final overallStopwatch = Stopwatch()..start();

    await _ensureSession();
    final session = _session!;
    final inputName = _inputName!;
    final outputName = _outputName!;

    CotsLogger.info('Spawning Dart background isolate for image decoding and downscaling...');
    final decodeStopwatch = Stopwatch()..start();
    final decoded = await compute(_decodeAndDownscale, imageBytes);
    decodeStopwatch.stop();

    if (decoded == null) {
      CotsLogger.warn('Image decoding failed inside background isolate.');
      throw FormatException('Could not decode image for detection.');
    }

    final double memoryMb = (decoded.width * decoded.height * 4) / (1024 * 1024);
    CotsLogger.success('Background decode completed in ${decodeStopwatch.elapsedMilliseconds} ms. Image size: ${decoded.width}x${decoded.height} px (~${memoryMb.toStringAsFixed(2)} MB raw memory).');

    CotsLogger.info('Executing YOLOv8 aspect-preserved preprocessing/letterboxing...');
    final preprocessStopwatch = Stopwatch()..start();
    final preprocessed = _preprocessor.preprocess(decoded);
    preprocessStopwatch.stop();
    CotsLogger.success('Preprocessing finished in ${preprocessStopwatch.elapsedMilliseconds} ms. Input size: ${_preprocessor.inputSize}x${_preprocessor.inputSize} (NCHW tensor).');

    OrtValue? inputTensor;
    try {
      inputTensor = await OrtValue.fromList(
        preprocessed.tensor,
        [1, 3, _preprocessor.inputSize, _preprocessor.inputSize],
      );

      CotsLogger.info('Running ONNX model inference...');
      final inferenceStopwatch = Stopwatch()..start();
      final outputs = await session.run({inputName: inputTensor});
      inferenceStopwatch.stop();
      CotsLogger.success('ONNX inference finished in ${inferenceStopwatch.elapsedMilliseconds} ms.');

      final outputTensor = outputs[outputName] ?? outputs.values.first;

      try {
        CotsLogger.info('Decoding YOLO bounding boxes and applying Non-Maximum Suppression (NMS)...');
        final postprocessStopwatch = Stopwatch()..start();
        final flat = await outputTensor.asFlattenedList();
        final shape = List<int>.from(outputTensor.shape);
        final boxes = _postprocessor.decode(flat, shape, preprocessed.meta);
        final result = summarize(boxes);
        postprocessStopwatch.stop();

        overallStopwatch.stop();
        CotsLogger.success('Postprocessing finished in ${postprocessStopwatch.elapsedMilliseconds} ms.');
        CotsLogger.success('Pipeline finished in ${overallStopwatch.elapsedMilliseconds} ms. Found ${result.count} COTS starfish with average confidence ${(result.confidence * 100).toStringAsFixed(1)}%.');
        return result;
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

/// Decodes and downscales raw image bytes inside a background isolate.
///
/// Restricts maximum dimensions to 2048px to prevent heap exhaustion before
/// the primary YOLO preprocessing resizing step.
img.Image? _decodeAndDownscale(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return null;

  const int maxDimension = 2048;
  if (image.width > maxDimension || image.height > maxDimension) {
    final double scale = image.width > image.height
        ? maxDimension / image.width
        : maxDimension / image.height;
    return img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
      interpolation: img.Interpolation.linear,
    );
  }
  return image;
}
