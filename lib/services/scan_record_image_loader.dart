import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/firebase_bootstrap.dart';
import '../models/record_collection.dart';
import '../utils/scan_record_image.dart';
import 'capture_image_store.dart';
import 'removal_record_image_store.dart';
import 'scan_record_image_store.dart';
import 'scan_record_repository.dart';
import 'storage_service.dart';
import 'windows_storage_rest_service.dart';

/// Loads submitted scan images from Firestore, local path, URL, or Storage.
abstract final class ScanRecordImageLoader {
  static Future<Uint8List?> loadBytes({
    String? recordId,
    required String? imageUrl,
    required String? imagePath,
    String? storageObjectPath,
    String recordCollection = RecordCollection.legacyScanRecords,
  }) async {
    final local = _loadLocal(imagePath);
    if (local != null) return local;

    if (recordId != null && recordId.trim().isNotEmpty) {
      final fromFirestore = await _loadFromFirestore(
        recordId: recordId,
        recordCollection: recordCollection,
      );
      if (fromFirestore != null && fromFirestore.isNotEmpty) {
        return fromFirestore;
      }
    }

    final url = imageUrl?.trim();
    if (url != null && url.startsWith('http')) {
      final fromUrl = await _loadHttp(url);
      if (fromUrl != null) return fromUrl;
    }

    final objectPath = ScanRecordImage.resolveStorageObjectPath(
      storageObjectPath: storageObjectPath,
      imageUrl: imageUrl,
    );
    if (objectPath == null || objectPath.isEmpty) return null;

    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) return null;
      return WindowsStorageRestService().downloadBytes(
        idToken: token,
        objectPath: objectPath,
      );
    }

    await ensureFirebaseInitialized();
    return StorageService().downloadBytes(objectPath: objectPath);
  }

  static Future<Uint8List?> _loadFromFirestore({
    required String recordId,
    required String recordCollection,
  }) async {
    switch (recordCollection) {
      case RecordCollection.captures:
        return CaptureImageStore.load(captureId: recordId);
      case RecordCollection.removalRecords:
        final removal = await RemovalRecordImageStore.load(removalId: recordId);
        if (removal != null) return removal;
        return CaptureImageStore.load(captureId: recordId);
      case RecordCollection.legacyScanRecords:
      default:
        return ScanRecordImageStore.load(recordId: recordId);
    }
  }

  static Uint8List? _loadLocal(String? imagePath) {
    final path = imagePath?.trim() ?? '';
    if (path.isEmpty || path.startsWith('http')) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file.readAsBytesSync();
  }

  static Future<Uint8List?> _loadHttp(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }
}
