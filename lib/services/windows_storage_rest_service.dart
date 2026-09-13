import 'dart:convert';

import 'dart:typed_data';



import 'package:http/http.dart' as http;



import '../firebase_options.dart';

import '../utils/scan_record_image.dart';

import 'storage_service.dart';



/// Firebase Storage uploads over HTTPS for Windows desktop.

///

/// The native [firebase_storage] plugin on Windows does not receive the REST

/// auth session, so uploads fail and [getDownloadURL] returns object-not-found.

class WindowsStorageRestService {

  WindowsStorageRestService({http.Client? client})

      : _client = client ?? http.Client();



  final http.Client _client;



  static final _bucket = DefaultFirebaseOptions.windows.storageBucket!;



  /// Uploads to `scan_records/{uid}/{scanId}/{filename}` and returns URLs.

  Future<ScanImageUploadResult> uploadScanImageBytes({

    required String idToken,

    required String uid,

    required String scanId,

    required Uint8List bytes,

    required String filename,

    String? contentType,

  }) async {

    if (bytes.isEmpty) {

      throw WindowsStorageRestException(

        'Scan image is empty — pick a photo and try again.',

      );

    }



    final safeName = ScanRecordImage.safeStorageFilename(filename);

    final objectPath = ScanRecordImage.scanObjectPath(

      uid: uid,

      scanId: scanId,

      filename: safeName,

    );

    final type = contentType ?? ScanRecordImage.contentTypeForFilename(safeName);



    final uri = Uri.https(

      'firebasestorage.googleapis.com',

      '/v0/b/$_bucket/o',

      {'uploadType': 'media', 'name': objectPath},

    );



    final response = await _client.post(

      uri,

      headers: {

        'Authorization': 'Bearer $idToken',

        'Content-Type': type,

      },

      body: bytes,

    );



    if (response.statusCode < 200 || response.statusCode >= 300) {

      throw WindowsStorageRestException(

        'Could not upload scan image (${response.statusCode}). '

        'Enable Storage in Firebase Console, then run: firebase deploy --only storage',

        body: response.body,

      );

    }



    final meta = jsonDecode(response.body) as Map<String, dynamic>;

    return ScanImageUploadResult(

      downloadUrl: _downloadUrlFromMetadata(meta),

      storageObjectPath: objectPath,

    );

  }



  Future<Uint8List?> downloadBytes({

    required String idToken,

    required String objectPath,

  }) async {

    final encodedName = Uri.encodeComponent(objectPath);

    final uri = Uri.parse(

      'https://firebasestorage.googleapis.com/v0/b/$_bucket/o/$encodedName?alt=media',

    );



    final response = await _client.get(

      uri,

      headers: {'Authorization': 'Bearer $idToken'},

    );

    if (response.statusCode >= 200 && response.statusCode < 300) {

      return response.bodyBytes;

    }

    return null;

  }



  static String _downloadUrlFromMetadata(Map<String, dynamic> meta) {

    final name = meta['name'] as String? ?? '';

    final bucket = meta['bucket'] as String? ?? _bucket;

    final tokensRaw = meta['downloadTokens']?.toString() ?? '';

    final token = tokensRaw.split(',').firstWhere(

          (t) => t.trim().isNotEmpty,

          orElse: () => '',

        );



    final encodedName = Uri.encodeComponent(name);

    final base =

        'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedName?alt=media';

    if (token.isEmpty) return base;

    return '$base&token=$token';

  }

}



class WindowsStorageRestException implements Exception {

  WindowsStorageRestException(this.message, {this.body});



  final String message;

  final String? body;



  @override

  String toString() {

    if (body == null || body!.trim().isEmpty) return message;

    return '$message\n$body';

  }

}

