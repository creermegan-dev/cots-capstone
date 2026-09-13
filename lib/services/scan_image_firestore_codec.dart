import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Compresses scan photos so they fit in Firestore (free plan, no Storage needed).
abstract final class ScanImageFirestoreCodec {
  /// Target raw JPEG size — leaves room for metadata in the 1 MiB doc limit.
  static const maxRawBytes = 520000;

  static Uint8List compressForFirestore(Uint8List input) {
    if (input.isEmpty) {
      throw ArgumentError('Scan image is empty.');
    }

    final decoded = img.decodeImage(input);
    if (decoded == null) {
      if (input.length <= maxRawBytes) return input;
      throw ArgumentError('Could not compress image for upload.');
    }

    var working = decoded;
    if (working.width > 1600 || working.height > 1600) {
      working = img.copyResize(
        working,
        width: working.width >= working.height ? 1600 : null,
        height: working.height > working.width ? 1600 : null,
      );
    }

    for (final quality in [85, 75, 65, 55, 45, 35, 28]) {
      final jpg = Uint8List.fromList(img.encodeJpg(working, quality: quality));
      if (jpg.length <= maxRawBytes) return jpg;
    }

    working = img.copyResize(working, width: 960);
    for (final quality in [45, 35, 28, 22]) {
      final jpg = Uint8List.fromList(img.encodeJpg(working, quality: quality));
      if (jpg.length <= maxRawBytes) return jpg;
    }

    throw ArgumentError(
      'Photo is too large even after compression. Try a smaller image.',
    );
  }

  static Uint8List? decodeBase64(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;
    try {
      final bytes = base64Decode(raw);
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }
}
