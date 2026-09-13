import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../core/firebase_bootstrap.dart';
import '../firebase_options.dart';
import '../models/record_collection.dart';
import 'scan_image_firestore_codec.dart';
import 'scan_record_repository.dart';

/// Stores compressed capture photos in `capture_images` after AI processing.
abstract final class CaptureImageStore {
  static CollectionReference<Map<String, dynamic>> get _nativeCollection =>
      FirebaseFirestore.instance.collection(RecordCollection.captureImages);

  static Future<void> save({
    required String captureId,
    required String uid,
    required Uint8List imageBytes,
  }) async {
    final compressed = ScanImageFirestoreCodec.compressForFirestore(imageBytes);
    final payload = {
      'capture_id': captureId,
      'uid': uid,
      'content_type': 'image/jpeg',
      'image_data_base64': base64Encode(compressed),
      'byte_size': compressed.length,
      'saved_at': FieldValue.serverTimestamp(),
    };

    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) {
        throw StateError('Not signed in — cannot save capture image.');
      }
      await _saveWindows(
        idToken: token,
        captureId: captureId,
        payload: payload,
      );
      return;
    }

    await ensureFirebaseInitialized();
    await _nativeCollection.doc(captureId).set(payload);
  }

  static Future<Uint8List?> load({required String captureId}) async {
    if (captureId.trim().isEmpty) return null;

    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) return null;
      final fromNew = await _loadWindows(
        idToken: token,
        collection: RecordCollection.captureImages,
        documentId: captureId,
      );
      if (fromNew != null) return fromNew;
      return _loadWindows(
        idToken: token,
        collection: RecordCollection.legacyScanRecordImages,
        documentId: captureId,
      );
    }

    await ensureFirebaseInitialized();
    final snap = await _nativeCollection.doc(captureId).get();
    if (snap.exists) {
      return ScanImageFirestoreCodec.decodeBase64(
        snap.data()?['image_data_base64'] as String?,
      );
    }

    final legacy = await FirebaseFirestore.instance
        .collection(RecordCollection.legacyScanRecordImages)
        .doc(captureId)
        .get();
    if (!legacy.exists) return null;
    return ScanImageFirestoreCodec.decodeBase64(
      legacy.data()?['image_data_base64'] as String?,
    );
  }

  static Future<void> _saveWindows({
    required String idToken,
    required String captureId,
    required Map<String, dynamic> payload,
  }) async {
    final projectId = DefaultFirebaseOptions.windows.projectId;
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId'
      '/databases/(default)/documents/${RecordCollection.captureImages}/$captureId',
    );

    final fields = <String, dynamic>{
      'capture_id': {'stringValue': payload['capture_id']},
      'uid': {'stringValue': payload['uid']},
      'content_type': {'stringValue': payload['content_type']},
      'image_data_base64': {'stringValue': payload['image_data_base64']},
      'byte_size': {'integerValue': '${payload['byte_size']}'},
      'saved_at': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
    };

    final client = http.Client();
    try {
      final response = await client.patch(
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fields': fields}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Could not save capture image (${response.statusCode}).',
        );
      }
    } finally {
      client.close();
    }
  }

  static Future<Uint8List?> _loadWindows({
    required String idToken,
    required String collection,
    required String documentId,
  }) async {
    final projectId = DefaultFirebaseOptions.windows.projectId;
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId'
      '/databases/(default)/documents/$collection/$documentId',
    );

    final client = http.Client();
    try {
      final response = await client.get(
        uri,
        headers: {'Authorization': 'Bearer $idToken'},
      );
      if (response.statusCode == 404) return null;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final fields = decoded['fields'] as Map<String, dynamic>? ?? {};
      final raw = fields['image_data_base64'];
      if (raw is Map && raw['stringValue'] is String) {
        return ScanImageFirestoreCodec.decodeBase64(raw['stringValue'] as String);
      }
      return null;
    } finally {
      client.close();
    }
  }
}
