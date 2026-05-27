import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Letterbox resize metadata for mapping model coords back to source image.
class LetterboxMeta {
  const LetterboxMeta({
    required this.scale,
    required this.padX,
    required this.padY,
    required this.inputSize,
    required this.sourceWidth,
    required this.sourceHeight,
  });

  final double scale;
  final int padX;
  final int padY;
  final int inputSize;
  final int sourceWidth;
  final int sourceHeight;
}

class YoloPreprocessResult {
  const YoloPreprocessResult({
    required this.tensor,
    required this.meta,
  });

  final Float32List tensor;
  final LetterboxMeta meta;
}

/// YOLOv8-style letterbox preprocess: RGB, /255, NCHW.
class YoloImagePreprocessor {
  const YoloImagePreprocessor({this.inputSize = 640});

  final int inputSize;

  YoloPreprocessResult preprocess(img.Image source) {
    final meta = _letterboxMeta(source.width, source.height);
    final canvas = img.Image(width: inputSize, height: inputSize);
    img.fill(canvas, color: img.ColorRgb8(114, 114, 114));

    final resized = img.copyResize(
      source,
      width: (source.width * meta.scale).round(),
      height: (source.height * meta.scale).round(),
      interpolation: img.Interpolation.linear,
    );
    img.compositeImage(canvas, resized, dstX: meta.padX, dstY: meta.padY);

    final tensor = Float32List(inputSize * inputSize * 3);
    var index = 0;
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final pixel = canvas.getPixel(x, y);
        tensor[index++] = pixel.r / 255.0;
        tensor[index++] = pixel.g / 255.0;
        tensor[index++] = pixel.b / 255.0;
      }
    }

    return YoloPreprocessResult(tensor: tensor, meta: meta);
  }

  LetterboxMeta _letterboxMeta(int width, int height) {
    final scale = math.min(inputSize / width, inputSize / height);
    final newW = (width * scale).round();
    final newH = (height * scale).round();
    final padX = ((inputSize - newW) / 2).floor();
    final padY = ((inputSize - newH) / 2).floor();
    return LetterboxMeta(
      scale: scale,
      padX: padX,
      padY: padY,
      inputSize: inputSize,
      sourceWidth: width,
      sourceHeight: height,
    );
  }
}
