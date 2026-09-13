import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../core/firebase_bootstrap.dart';
import '../firebase_options.dart';
import '../models/record_collection.dart';
import 'scan_image_firestore_codec.dart';
import 'scan_record_repository.dart';

/// Stores compressed removal proof photos in `removal_record_images`.
abstract final class RemovalRecordImageStore {
  static CollectionReference<Map<String, dynamic>> get _nativeCollection =>
      FirebaseFirestore.instance
          .collection(RecordCollection.removalRecordImages);

  static Future<void> save({
    required String removalId,
    required String uid,
    required String captureId,
    required Uint8List imageBytes,
  }) async {
    final compressed = ScanImageFirestoreCodec.compressForFirestore(imageBytes);
    final payload = {
      'removal_id': removalId,
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
        throw StateError('Not signed in — cannot save removal image.');
      }
      await _saveWindows(
        idToken: token,
        removalId: removalId,
        payload: payload,
      );
      return;
    }

    await ensureFirebaseInitialized();
    await _nativeCollection.doc(removalId).set(payload);
  }

  static Future<Uint8List?> load({required String removalId}) async {
    if (removalId.trim().isEmpty) return null;

    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) return null;
      return _loadWindows(idToken: token, removalId: removalId);
    }

    await ensureFirebaseInitialized();
    final snap = await _nativeCollection.doc(removalId).get();
    if (!snap.exists) return null;
    return ScanImageFirestoreCodec.decodeBase64(
      snap.data()?['image_data_base64'] as String?,
    );
  }

  static Future<void> _saveWindows({
    required String idToken,
    required String removalId,
    required Map<String, dynamic> payload,
  }) async {
    final projectId = DefaultFirebaseOptions.windows.projectId;
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId'
      '/databases/(default)/documents/${RecordCollection.removalRecordImages}/$removalId',
    );

    final fields = <String, dynamic>{
      'removal_id': {'stringValue': payload['removal_id']},
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
          'Could not save removal image (${response.statusCode}).',
        );
      }
    } finally {
      client.close();
    }
  }

  static Future<Uint8List?> _loadWindows({
    required String idToken,
    required String removalId,
  }) async {
    final projectId = DefaultFirebaseOptions.windows.projectId;
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId'
      '/databases/(default)/documents/${RecordCollection.removalRecordImages}/$removalId',
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
