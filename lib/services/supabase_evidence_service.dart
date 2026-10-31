import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

enum EvidencePurpose { detection, elimination }

enum EvidenceUploadStage {
  prepared,
  assetReserved,
  variantReserved,
  uploaded,
  linked,
  verificationRequested,
  awaitingVerification,
}

enum EvidenceServerState {
  queued,
  waitingPrerequisite,
  finalized,
  rejected,
}

typedef EvidenceProgressCallback = Future<void> Function(
  EvidenceUploadStage stage,
);

class EvidenceImagePayload {
  const EvidenceImagePayload({
    required this.bytes,
    required this.originalName,
    required this.originalSha256,
    required this.originalByteSize,
    required this.rawWidth,
    required this.rawHeight,
    required this.sha256Hex,
    required this.width,
    required this.height,
  });

  static const mimeType = 'image/jpeg';
  static const format = 'jpeg';
  static const encoder = 'image-4.10.0/jpeg-82-bake-orientation';
  static const maxTrustedBytes = 5 * 1024 * 1024;
  static const maxTrustedPixels = 24000000;
  static const maxTrustedDimension = 8192;

  final Uint8List bytes;
  final String originalName;
  final String originalSha256;
  final int originalByteSize;
  final int rawWidth;
  final int rawHeight;
  final String sha256Hex;
  final int width;
  final int height;

  int get byteSize => bytes.length;

  static EvidenceImagePayload prepare({
    required Uint8List originalBytes,
    required String originalName,
  }) {
    if (originalBytes.isEmpty) {
      throw ArgumentError('Evidence image is empty.');
    }
    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      throw const FormatException('Could not decode the evidence image.');
    }
    final oriented = img.bakeOrientation(decoded);
    if (oriented.width > maxTrustedDimension ||
        oriented.height > maxTrustedDimension ||
        oriented.width * oriented.height > maxTrustedPixels) {
      throw ArgumentError(
        'Evidence dimensions exceed the trusted verifier limit.',
      );
    }
    final encoded = Uint8List.fromList(img.encodeJpg(oriented, quality: 82));
    if (encoded.length > maxTrustedBytes) {
      throw ArgumentError(
        'Prepared evidence exceeds the 5 MiB trusted verification limit.',
      );
    }
    return EvidenceImagePayload(
      bytes: encoded,
      originalName: originalName.trim(),
      originalSha256: sha256.convert(originalBytes).toString(),
      originalByteSize: originalBytes.length,
      rawWidth: decoded.width,
      rawHeight: decoded.height,
      sha256Hex: sha256.convert(encoded).toString(),
      width: oriented.width,
      height: oriented.height,
    );
  }

  Map<String, dynamic> toMetadata() => {
        'original_name': originalName,
        'original_sha256': originalSha256,
        'original_byte_size': originalByteSize,
        'raw_width': rawWidth,
        'raw_height': rawHeight,
        'sha256': sha256Hex,
        'byte_size': byteSize,
        'width': width,
        'height': height,
        'format': format,
        'mime_type': mimeType,
        'encoder': encoder,
      };

  factory EvidenceImagePayload.fromMetadata(
    Map<String, dynamic> metadata,
    Uint8List bytes,
  ) {
    final payload = EvidenceImagePayload(
      bytes: bytes,
      originalName: metadata['original_name']?.toString() ?? '',
      originalSha256: metadata['original_sha256']?.toString() ?? '',
      originalByteSize: (metadata['original_byte_size'] as num?)?.round() ?? 0,
      rawWidth: (metadata['raw_width'] as num?)?.round() ?? 0,
      rawHeight: (metadata['raw_height'] as num?)?.round() ?? 0,
      sha256Hex: metadata['sha256']?.toString() ?? '',
      width: (metadata['width'] as num?)?.round() ?? 0,
      height: (metadata['height'] as num?)?.round() ?? 0,
    );
    if (payload.originalName.isEmpty ||
        payload.originalSha256.length != 64 ||
        payload.originalByteSize <= 0 ||
        payload.rawWidth <= 0 ||
        payload.rawHeight <= 0 ||
        payload.width <= 0 ||
        payload.height <= 0 ||
        payload.byteSize != (metadata['byte_size'] as num?)?.round() ||
        payload.sha256Hex != sha256.convert(bytes).toString()) {
      throw StateError('Saved evidence bytes do not match their manifest.');
    }
    return payload;
  }
}

class EvidenceAuthorizationException implements Exception {
  const EvidenceAuthorizationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class EvidenceNetworkException implements Exception {
  const EvidenceNetworkException(this.message);
  final String message;

  @override
  String toString() => message;
}

class EvidenceUploadException implements Exception {
  const EvidenceUploadException(this.message);
  final String message;

  @override
  String toString() => message;
}

class EvidenceReservationConflictException implements Exception {
  const EvidenceReservationConflictException(this.message);
  final String message;

  @override
  String toString() => message;
}

class EvidenceRejectedException implements Exception {
  const EvidenceRejectedException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract interface class EvidenceGateway {
  Future<Map<String, dynamic>?> getAsset(String id);
  Future<void> insertAsset(Map<String, dynamic> row);
  Future<Map<String, dynamic>?> getVariant(String id);
  Future<void> insertVariant(Map<String, dynamic> row);
  Future<void> upload(String bucket, String path, Uint8List bytes);
  Future<Uint8List> download(String bucket, String path);
  Future<void> link(String targetKind, String targetId, String variantId);
  Future<Map<String, dynamic>?> requestVerification(String variantId);
}

class SupabaseEvidenceGateway implements EvidenceGateway {
  SupabaseEvidenceGateway(this.client);

  final SupabaseClient client;

  @override
  Future<Map<String, dynamic>?> getAsset(String id) async {
    final row =
        await client.from('media_assets').select().eq('id', id).maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  @override
  Future<void> insertAsset(Map<String, dynamic> row) async {
    await client.from('media_assets').insert(row);
  }

  @override
  Future<Map<String, dynamic>?> getVariant(String id) async {
    final row =
        await client.from('media_variants').select().eq('id', id).maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  @override
  Future<void> insertVariant(Map<String, dynamic> row) async {
    await client.from('media_variants').insert(row);
  }

  @override
  Future<void> upload(String bucket, String path, Uint8List bytes) async {
    await client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            cacheControl: 'private, max-age=300',
            contentType: EvidenceImagePayload.mimeType,
            upsert: false,
          ),
          retryAttempts: 1,
        );
  }

  @override
  Future<Uint8List> download(String bucket, String path) {
    return client.storage.from(bucket).download(path);
  }

  @override
  Future<void> link(
      String targetKind, String targetId, String variantId) async {
    await client.rpc<void>('link_evidence', params: {
      'target_kind': targetKind,
      'target': targetId,
      'variant': variantId,
    });
  }

  @override
  Future<Map<String, dynamic>?> requestVerification(String variantId) async {
    final response = await client.functions.invoke(
      'verify-evidence',
      body: {'variant_id': variantId},
    );
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }
}

class EvidenceReservation {
  const EvidenceReservation({
    required this.assetId,
    required this.variantId,
    required this.bucket,
    required this.objectPath,
    required this.serverState,
  });

  final String assetId;
  final String variantId;
  final String bucket;
  final String objectPath;
  final EvidenceServerState serverState;
}

class SupabaseEvidenceService {
  SupabaseEvidenceService({EvidenceGateway? gateway})
      : _gateway = gateway ?? SupabaseEvidenceGateway(Supabase.instance.client);

  final EvidenceGateway _gateway;

  Future<EvidenceReservation> reserveUploadAndLink({
    required EvidencePurpose purpose,
    required String ownerId,
    required String targetId,
    required String assetId,
    required String assetIdempotencyKey,
    required String variantId,
    required EvidenceImagePayload payload,
    required DateTime capturedAt,
    required String captureTimeSource,
    EvidenceProgressCallback? onProgress,
  }) async {
    final bucket = purpose == EvidencePurpose.detection
        ? 'detection-evidence'
        : 'elimination-evidence';
    final targetKind =
        purpose == EvidencePurpose.detection ? 'capture' : 'elimination';
    final objectPath = '$ownerId/$assetId/$variantId';
    final asset = <String, dynamic>{
      'id': assetId,
      'owner_id': ownerId,
      'idempotency_key': assetIdempotencyKey,
      'original_name': payload.originalName,
      'original_sha256': payload.originalSha256,
      'original_bytes': payload.originalByteSize,
      'raw_width': payload.rawWidth,
      'raw_height': payload.rawHeight,
      'source_width': payload.width,
      'source_height': payload.height,
      'captured_at': capturedAt.toUtc().toIso8601String(),
      'capture_time_source': captureTimeSource,
      'original_time_text': capturedAt.toUtc().toIso8601String(),
      'timezone_assumed': false,
    };
    final variant = <String, dynamic>{
      'id': variantId,
      'asset_id': assetId,
      'kind': 'evidence',
      'version': 1,
      'bucket': bucket,
      'object_path': objectPath,
      'format': EvidenceImagePayload.format,
      'mime_type': EvidenceImagePayload.mimeType,
      'width': payload.width,
      'height': payload.height,
      'byte_size': payload.byteSize,
      'sha256': payload.sha256Hex,
      'encoder': EvidenceImagePayload.encoder,
      'encoder_settings': const {'quality': 82, 'orientation_baked': true},
    };

    var serverState = EvidenceServerState.queued;

    try {
      await _reserveAsset(asset);
      await onProgress?.call(EvidenceUploadStage.assetReserved);
      await _reserveVariant(variant);
      await onProgress?.call(EvidenceUploadStage.variantReserved);
      await _uploadOrRecover(bucket, objectPath, payload);
      await onProgress?.call(EvidenceUploadStage.uploaded);
      await _gateway.link(targetKind, targetId, variantId);
      await onProgress?.call(EvidenceUploadStage.linked);
      try {
        final response = await _gateway.requestVerification(variantId);
        serverState = _serverState(response);
        await onProgress?.call(EvidenceUploadStage.verificationRequested);
        if (serverState == EvidenceServerState.rejected) {
          throw const EvidenceRejectedException(
            'The trusted server rejected this evidence. The local photo was preserved for review.',
          );
        }
      } catch (error) {
        if (error is EvidenceRejectedException) rethrow;
        // Storage/link triggers already queued the immutable object. A failed
        // low-latency request must not restart or duplicate the upload.
        serverState = EvidenceServerState.queued;
      }
      await onProgress?.call(EvidenceUploadStage.awaitingVerification);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(_classify(error), stackTrace);
    }

    return EvidenceReservation(
      assetId: assetId,
      variantId: variantId,
      bucket: bucket,
      objectPath: objectPath,
      serverState: serverState,
    );
  }

  static EvidenceServerState _serverState(Map<String, dynamic>? response) {
    final processed = response?['processed'];
    if (processed is List && processed.isNotEmpty && processed.first is Map) {
      final state = (processed.first as Map)['state']?.toString();
      if (state == 'finalized') return EvidenceServerState.finalized;
      if (state == 'waiting_prerequisite') {
        return EvidenceServerState.waitingPrerequisite;
      }
      if (state == 'rejected') return EvidenceServerState.rejected;
    }
    return EvidenceServerState.queued;
  }

  Future<void> _reserveAsset(Map<String, dynamic> expected) async {
    var saved = await _gateway.getAsset(expected['id'] as String);
    if (saved == null) {
      try {
        await _gateway.insertAsset(expected);
      } catch (_) {
        saved = await _gateway.getAsset(expected['id'] as String);
        if (saved == null) rethrow;
      }
    }
    saved ??= expected;
    _requireMatching(
      saved,
      expected,
      const [
        'id',
        'owner_id',
        'idempotency_key',
        'original_name',
        'original_sha256',
        'original_bytes',
        'raw_width',
        'raw_height',
        'source_width',
        'source_height',
      ],
      'media asset',
    );
  }

  Future<void> _reserveVariant(Map<String, dynamic> expected) async {
    var saved = await _gateway.getVariant(expected['id'] as String);
    if (saved == null) {
      try {
        await _gateway.insertVariant(expected);
      } catch (_) {
        saved = await _gateway.getVariant(expected['id'] as String);
        if (saved == null) rethrow;
      }
    }
    saved ??= expected;
    _requireMatching(
      saved,
      expected,
      const [
        'id',
        'asset_id',
        'kind',
        'version',
        'bucket',
        'object_path',
        'format',
        'mime_type',
        'width',
        'height',
        'byte_size',
        'sha256',
        'encoder',
      ],
      'media variant',
    );
  }

  void _requireMatching(
    Map<String, dynamic> saved,
    Map<String, dynamic> expected,
    List<String> keys,
    String label,
  ) {
    for (final key in keys) {
      if (saved[key]?.toString() != expected[key]?.toString()) {
        throw EvidenceReservationConflictException(
          'The saved $label differs from this retry; existing evidence was preserved.',
        );
      }
    }
  }

  Future<void> _uploadOrRecover(
    String bucket,
    String path,
    EvidenceImagePayload payload,
  ) async {
    Object? uploadError;
    try {
      await _gateway.upload(bucket, path, payload.bytes);
    } catch (error) {
      uploadError = error;
    }

    try {
      final stored = await _gateway.download(bucket, path);
      if (stored.length != payload.byteSize ||
          sha256.convert(stored).toString() != payload.sha256Hex) {
        throw const EvidenceReservationConflictException(
          'An immutable evidence object already exists with different bytes.',
        );
      }
    } catch (error) {
      if (uploadError != null) throw uploadError;
      rethrow;
    }
  }

  Object _classify(Object error) {
    if (error is EvidenceAuthorizationException ||
        error is EvidenceNetworkException ||
        error is EvidenceUploadException ||
        error is EvidenceReservationConflictException ||
        error is EvidenceRejectedException) {
      return error;
    }
    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return EvidenceNetworkException(
          'Evidence synchronization failed: $error');
    }
    if (error is StorageException) {
      final code = int.tryParse(error.statusCode ?? '');
      if (code == 401 || code == 403) {
        return const EvidenceAuthorizationException(
          'This account is not authorized to access the reserved evidence object.',
        );
      }
      return EvidenceUploadException(
          'Evidence upload failed: ${error.message}');
    }
    if (error is PostgrestException) {
      if (error.code == '42501' || error.code == '401' || error.code == '403') {
        return const EvidenceAuthorizationException(
          'This account is not authorized to reserve or link this evidence.',
        );
      }
      return EvidenceUploadException(
        'Evidence metadata could not be saved: ${error.message}',
      );
    }
    return error;
  }
}

abstract final class PrivateEvidenceSessionGuard {
  static Future<Uint8List?> download({
    required String? Function() sessionKey,
    required Future<Uint8List> Function() downloader,
  }) async {
    final before = sessionKey();
    if (before == null || before.isEmpty) return null;
    try {
      final bytes = await downloader();
      if (sessionKey() != before) return null;
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }
}
