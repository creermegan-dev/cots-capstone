import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../lib/services/scan_image_firestore_codec.dart';

void main() {
  // Synthetic 4000x3000 photo (large gallery pick).
  final synthetic = img.Image(width: 4000, height: 3000);
  img.fill(synthetic, color: img.ColorRgb8(20, 120, 180));
  final raw = Uint8List.fromList(img.encodeJpg(synthetic, quality: 95));

  final compressed = ScanImageFirestoreCodec.compressForFirestore(raw);
  final base64Len = base64Encode(compressed).length;

  print('raw_jpeg_bytes=${raw.length}');
  print('compressed_bytes=${compressed.length}');
  print('base64_chars=$base64Len');
  print('under_firestore_1mb=${base64Len < 900000}');
  print('roundtrip_ok=${ScanImageFirestoreCodec.decodeBase64(base64Encode(compressed)) != null}');

  if (compressed.length > ScanImageFirestoreCodec.maxRawBytes) {
    stderr.writeln('FAIL: compressed too large');
    exit(1);
  }
  if (base64Len >= 1048576) {
    stderr.writeln('FAIL: base64 exceeds Firestore doc limit');
    exit(1);
  }
  print('PASS');
}
