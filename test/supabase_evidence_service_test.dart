import 'dart:async';
import 'dart:typed_data';

import 'package:cots_monitor/services/supabase_evidence_service.dart';
import 'package:cots_monitor/services/supabase_record_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('Supabase evidence upload sequence', () {
    late _FakeEvidenceGateway gateway;
    late SupabaseEvidenceService service;
    late EvidenceImagePayload payload;

    setUp(() {
      gateway = _FakeEvidenceGateway();
      service = SupabaseEvidenceService(gateway: gateway);
      final source = img.Image(width: 3, height: 2)
        ..setPixelRgb(0, 0, 255, 0, 0);
      payload = EvidenceImagePayload.prepare(
        originalBytes: Uint8List.fromList(img.encodePng(source)),
        originalName: 'reef.png',
      );
    });

    test('reserves, uploads, links, and remains awaiting verification',
        () async {
      final stages = <EvidenceUploadStage>[];
      final result = await service.reserveUploadAndLink(
        purpose: EvidencePurpose.detection,
        ownerId: 'owner',
        targetId: 'capture',
        assetId: 'asset',
        assetIdempotencyKey: 'asset-key',
        variantId: 'variant',
        payload: payload,
        capturedAt: DateTime.utc(2026, 10, 29),
        captureTimeSource: 'device',
        onProgress: (stage) async => stages.add(stage),
      );

      expect(result.bucket, 'detection-evidence');
      expect(result.objectPath, 'owner/asset/variant');
      expect(gateway.objects['detection-evidence/owner/asset/variant'],
          payload.bytes);
      expect(gateway.links, {'capture:capture:variant'});
      expect(gateway.variants['variant']!['upload_status'], isNull);
      expect(stages.last, EvidenceUploadStage.awaitingVerification);
      expect(gateway.downloadAttempts, 0);
      expect(gateway.assetReads, 0);
      expect(gateway.variantReads, 0);
    });

    test('recovers when upload succeeded but its response was lost', () async {
      gateway.loseNextUploadResponse = true;

      await service.reserveUploadAndLink(
        purpose: EvidencePurpose.detection,
        ownerId: 'owner',
        targetId: 'capture',
        assetId: 'asset',
        assetIdempotencyKey: 'asset-key',
        variantId: 'variant',
        payload: payload,
        capturedAt: DateTime.utc(2026, 10, 29),
        captureTimeSource: 'device',
      );

      expect(gateway.objects, hasLength(1));
      expect(gateway.links, hasLength(1));
      expect(gateway.downloadAttempts, 1);
    });

    test('slow verification returns queued after safe upload and link',
        () async {
      final worker = Completer<Map<String, dynamic>?>();
      gateway.pendingVerification = worker.future;
      service = SupabaseEvidenceService(
        gateway: gateway,
        verificationWait: const Duration(milliseconds: 10),
      );
      final result = await service
          .reserveUploadAndLink(
            purpose: EvidencePurpose.detection,
            ownerId: 'owner',
            targetId: 'capture',
            assetId: 'asset',
            assetIdempotencyKey: 'asset-key',
            variantId: 'variant',
            payload: payload,
            capturedAt: DateTime.utc(2026, 10, 29),
            captureTimeSource: 'device',
          )
          .timeout(const Duration(seconds: 2));

      expect(result.serverState, EvidenceServerState.queued);
      expect(gateway.links, {'capture:capture:variant'});
      expect(gateway.objects.values.single, payload.bytes);
      expect(gateway.uploadAttempts, 1);
      expect(gateway.verificationRequests, 1);
      expect(worker.isCompleted, isFalse);
      // A late network error must be consumed without a second upload or an
      // unhandled async error after the screen has finished submitting.
      worker.completeError(const EvidenceNetworkException('late worker error'));
      await Future<void>.delayed(Duration.zero);
      expect(gateway.uploadAttempts, 1);
    });

    test('retry refuses an immutable object with different bytes', () async {
      gateway.objects['detection-evidence/owner/asset/variant'] =
          Uint8List.fromList([1, 2, 3]);
      await expectLater(
        service.reserveUploadAndLink(
          purpose: EvidencePurpose.detection,
          ownerId: 'owner',
          targetId: 'capture',
          assetId: 'asset',
          assetIdempotencyKey: 'asset-key',
          variantId: 'variant',
          payload: payload,
          capturedAt: DateTime.utc(2026, 10, 29),
          captureTimeSource: 'device',
        ),
        throwsA(isA<EvidenceUploadException>()),
      );
      expect(gateway.objects.values.single, [1, 2, 3]);
      expect(gateway.links, isEmpty);
      expect(gateway.verificationRequests, 0);
    });

    test('retry reuses matching metadata and immutable object', () async {
      Future<void> submit() => service.reserveUploadAndLink(
            purpose: EvidencePurpose.detection,
            ownerId: 'owner',
            targetId: 'capture',
            assetId: 'asset',
            assetIdempotencyKey: 'asset-key',
            variantId: 'variant',
            payload: payload,
            capturedAt: DateTime.utc(2026, 10, 29),
            captureTimeSource: 'device',
          );

      await submit();
      await submit();

      expect(gateway.assetInsertions, 1);
      expect(gateway.variantInsertions, 1);
      expect(gateway.objects, hasLength(1));
      expect(gateway.links, hasLength(1));
    });

    for (final lost in ['asset', 'variant']) {
      test('first-write reservation recovers a lost $lost response', () async {
        gateway.loseAssetResponse = lost == 'asset';
        gateway.loseVariantResponse = lost == 'variant';
        await service.reserveUploadAndLink(
          purpose: EvidencePurpose.detection,
          ownerId: 'owner',
          targetId: 'capture',
          assetId: 'asset',
          assetIdempotencyKey: 'key',
          variantId: 'variant',
          payload: payload,
          capturedAt: DateTime.utc(2026, 10, 29),
          captureTimeSource: 'exif',
        );
        expect(gateway.assetInsertions, 1);
        expect(gateway.variantInsertions, 1);
        expect(gateway.assetReads, lost == 'asset' ? 1 : 0);
        expect(gateway.variantReads, lost == 'variant' ? 1 : 0);
        expect(gateway.uploadAttempts, 1);
        expect(gateway.links, {'capture:capture:variant'});
      });
    }

    test('partial upload failure retains reservation and links only on retry',
        () async {
      gateway.failNextUploadBeforeStore = true;
      Future<EvidenceReservation> invocation() => service.reserveUploadAndLink(
            purpose: EvidencePurpose.elimination,
            ownerId: 'owner',
            targetId: 'elimination',
            assetId: 'removal-asset',
            assetIdempotencyKey: 'removal-asset-key',
            variantId: 'removal-variant',
            payload: payload,
            capturedAt: DateTime.utc(2026, 10, 29),
            captureTimeSource: 'exif',
          );

      await expectLater(invocation(), throwsA(isA<EvidenceNetworkException>()));
      expect(gateway.assets, contains('removal-asset'));
      expect(gateway.variants, contains('removal-variant'));
      expect(gateway.links, isEmpty);

      final recovered = await invocation();
      expect(recovered.bucket, 'elimination-evidence');
      expect(gateway.objects,
          contains('elimination-evidence/owner/removal-asset/removal-variant'));
      expect(gateway.links, {'elimination:elimination:removal-variant'});
    });

    test('same bytes use separate detection and elimination reservations',
        () async {
      await service.reserveUploadAndLink(
        purpose: EvidencePurpose.detection,
        ownerId: 'owner',
        targetId: 'capture',
        assetId: 'd-asset',
        assetIdempotencyKey: 'd-key',
        variantId: 'd-variant',
        payload: payload,
        capturedAt: DateTime.utc(2026, 10, 29),
        captureTimeSource: 'device',
      );
      await service.reserveUploadAndLink(
        purpose: EvidencePurpose.elimination,
        ownerId: 'owner',
        targetId: 'removal',
        assetId: 'e-asset',
        assetIdempotencyKey: 'e-key',
        variantId: 'e-variant',
        payload: payload,
        capturedAt: DateTime.utc(2026, 10, 29),
        captureTimeSource: 'device',
      );

      expect(gateway.objects.keys, {
        'detection-evidence/owner/d-asset/d-variant',
        'elimination-evidence/owner/e-asset/e-variant',
      });
      expect(gateway.objects.values, everyElement(payload.bytes));
    });

    for (final transport in ['copy', 'unsupported', 'lost response']) {
      test('same-photo removal preserves evidence with $transport', () async {
        const sourcePath = 'owner/d-asset/d-variant';
        gateway.objects['detection-evidence/$sourcePath'] = payload.bytes;
        gateway.failCopy = transport == 'unsupported';
        gateway.loseCopyResponse = transport == 'lost response';
        final result = await service.reserveUploadAndLink(
          purpose: EvidencePurpose.elimination,
          ownerId: 'owner',
          targetId: 'removal',
          assetId: 'e-asset',
          assetIdempotencyKey: 'e-key',
          variantId: 'e-variant',
          payload: payload,
          capturedAt: DateTime.utc(2026, 10, 29),
          captureTimeSource: 'exif',
          copyFrom: EvidenceCopySource(
              bucket: 'detection-evidence',
              objectPath: sourcePath,
              sha256Hex: payload.sha256Hex),
        );
        expect(result.bucket, 'elimination-evidence');
        expect(gateway.copyAttempts, 1);
        expect(gateway.uploadAttempts, transport == 'copy' ? 0 : 1);
        expect(
            gateway.objects['detection-evidence/$sourcePath'], payload.bytes);
        expect(gateway.objects['elimination-evidence/owner/e-asset/e-variant'],
            payload.bytes);
        expect(gateway.links, {'elimination:removal:e-variant'});
        expect(gateway.verificationRequests, 1);
      });
    }

    test('stalled server copy falls back without waiting indefinitely',
        () async {
      final copy = Completer<void>();
      gateway.pendingCopy = copy.future;
      service = SupabaseEvidenceService(
          gateway: gateway, copyWait: const Duration(milliseconds: 10));
      await service
          .reserveUploadAndLink(
            purpose: EvidencePurpose.elimination,
            ownerId: 'owner',
            targetId: 'removal',
            assetId: 'asset',
            assetIdempotencyKey: 'key',
            variantId: 'variant',
            payload: payload,
            capturedAt: DateTime.utc(2026, 10, 29),
            captureTimeSource: 'exif',
            copyFrom: EvidenceCopySource(
                bucket: 'detection-evidence',
                objectPath: 'owner/source/variant',
                sha256Hex: payload.sha256Hex),
          )
          .timeout(const Duration(seconds: 2));
      expect(gateway.uploadAttempts, 1);
      expect(gateway.links, {'elimination:removal:variant'});
      copy.completeError(const EvidenceNetworkException('late copy failure'));
      await Future<void>.delayed(Duration.zero);
    });

    for (final invalid in ['owner', 'hash', 'bucket']) {
      test('copy refuses mismatched $invalid before any reservation', () async {
        await expectLater(
            service.reserveUploadAndLink(
              purpose: EvidencePurpose.elimination,
              ownerId: 'owner',
              targetId: 'removal',
              assetId: 'asset',
              assetIdempotencyKey: 'key',
              variantId: 'variant',
              payload: payload,
              capturedAt: DateTime.utc(2026, 10, 29),
              captureTimeSource: 'exif',
              copyFrom: EvidenceCopySource(
                  bucket: invalid == 'bucket' ? 'other' : 'detection-evidence',
                  objectPath: invalid == 'owner'
                      ? 'another/source/v'
                      : 'owner/source/v',
                  sha256Hex:
                      invalid == 'hash' ? 'different' : payload.sha256Hex),
            ),
            throwsArgumentError);
        expect(gateway.assets, isEmpty);
        expect(gateway.uploadAttempts, 0);
        expect(gateway.copyAttempts, 0);
      });
    }

    test('copy source is bound to the new capture and exact prepared photo',
        () {
      final source = SupabaseRecordService.samePhotoCopySource(
          ownerId: 'owner',
          captureId: SupabaseRecordService.stableUuid('capture', 'photo'),
          captureSubmissionId: 'photo',
          evidence: payload);
      expect(source.objectPath,
          'owner/${SupabaseRecordService.stableUuid('detection-media-asset', 'photo')}/${SupabaseRecordService.stableUuid('detection-media-variant', 'photo')}');
      expect(source.sha256Hex, payload.sha256Hex);
      expect(
          () => SupabaseRecordService.samePhotoCopySource(
              ownerId: 'owner',
              captureId: 'older-capture',
              captureSubmissionId: 'photo',
              evidence: payload),
          throwsArgumentError);
    });

    test('mismatched retry is rejected without replacing evidence', () async {
      gateway.assets['asset'] = {
        'id': 'asset',
        'owner_id': 'different-owner',
      };

      await expectLater(
        service.reserveUploadAndLink(
          purpose: EvidencePurpose.detection,
          ownerId: 'owner',
          targetId: 'capture',
          assetId: 'asset',
          assetIdempotencyKey: 'asset-key',
          variantId: 'variant',
          payload: payload,
          capturedAt: DateTime.utc(2026, 10, 29),
          captureTimeSource: 'device',
        ),
        throwsA(isA<EvidenceReservationConflictException>()),
      );
      expect(gateway.objects, isEmpty);
    });

    test('server finalization result is surfaced without another upload',
        () async {
      gateway.verificationResponse = {
        'processed': [
          {'state': 'finalized'}
        ],
      };
      final result = await service.reserveUploadAndLink(
        purpose: EvidencePurpose.detection,
        ownerId: 'owner',
        targetId: 'capture',
        assetId: 'finalized-asset',
        assetIdempotencyKey: 'finalized-asset-key',
        variantId: 'finalized-variant',
        payload: payload,
        capturedAt: DateTime.utc(2026, 10, 29),
        captureTimeSource: 'exif',
      );

      expect(result.serverState, EvidenceServerState.finalized);
      expect(gateway.uploadAttempts, 1);
      expect(gateway.verificationRequests, 1);
    });

    test('worker request failure stays queued and never repeats the upload',
        () async {
      gateway.failVerificationRequest = true;
      final result = await service.reserveUploadAndLink(
        purpose: EvidencePurpose.detection,
        ownerId: 'owner',
        targetId: 'capture',
        assetId: 'queued-asset',
        assetIdempotencyKey: 'queued-asset-key',
        variantId: 'queued-variant',
        payload: payload,
        capturedAt: DateTime.utc(2026, 10, 29),
        captureTimeSource: 'exif',
      );

      expect(result.serverState, EvidenceServerState.queued);
      expect(gateway.uploadAttempts, 1);
      expect(gateway.links, {'capture:capture:queued-variant'});
    });

    test('trusted rejection is actionable and preserves immutable upload',
        () async {
      gateway.verificationResponse = {
        'processed': [
          {'state': 'rejected', 'code': 'sha256_mismatch'}
        ],
      };

      await expectLater(
        service.reserveUploadAndLink(
          purpose: EvidencePurpose.detection,
          ownerId: 'owner',
          targetId: 'capture',
          assetId: 'rejected-asset',
          assetIdempotencyKey: 'rejected-asset-key',
          variantId: 'rejected-variant',
          payload: payload,
          capturedAt: DateTime.utc(2026, 10, 29),
          captureTimeSource: 'exif',
        ),
        throwsA(isA<EvidenceRejectedException>()),
      );
      expect(gateway.uploadAttempts, 1);
      expect(gateway.objects, hasLength(1));
    });
  });

  test('private download is discarded if the authenticated session changes',
      () async {
    var session = 'user-a:token-a';
    final result = await PrivateEvidenceSessionGuard.download(
      sessionKey: () => session,
      downloader: () async {
        session = 'user-b:token-b';
        return Uint8List.fromList([1, 2, 3]);
      },
    );
    expect(result, isNull);

    session = 'user-a:token-a';
    final stable = await PrivateEvidenceSessionGuard.download(
      sessionKey: () => session,
      downloader: () async => Uint8List.fromList([1, 2, 3]),
    );
    expect(stable, [1, 2, 3]);
  });

  test('private download reports failures without returning private bytes',
      () async {
    Object? reported;
    final failure = StateError('test-only failure');
    final bytes = await PrivateEvidenceSessionGuard.download(
      sessionKey: () => 'user-a:token-a',
      downloader: () async => throw failure,
      onError: (error) => reported = error,
    );
    expect(bytes, isNull);
    expect(reported, same(failure));
  });
}

class _FakeEvidenceGateway implements EvidenceGateway, EvidenceCopyGateway {
  final assets = <String, Map<String, dynamic>>{};
  final variants = <String, Map<String, dynamic>>{};
  final objects = <String, Uint8List>{};
  final links = <String>{};
  var assetInsertions = 0;
  var variantInsertions = 0;
  var loseNextUploadResponse = false;
  var failNextUploadBeforeStore = false;
  var failVerificationRequest = false;
  var uploadAttempts = 0;
  var verificationRequests = 0;
  var downloadAttempts = 0;
  var assetReads = 0;
  var variantReads = 0;
  var copyAttempts = 0;
  var failCopy = false;
  var loseCopyResponse = false;
  var loseAssetResponse = false;
  var loseVariantResponse = false;
  Future<void>? pendingCopy;
  Future<Map<String, dynamic>?>? pendingVerification;
  Map<String, dynamic>? verificationResponse;

  @override
  Future<Map<String, dynamic>?> getAsset(String id) async {
    assetReads++;
    return assets[id];
  }

  @override
  Future<void> insertAsset(Map<String, dynamic> row) async {
    if (assets.containsKey(row['id'])) {
      throw const EvidenceUploadException('duplicate asset');
    }
    assetInsertions++;
    assets[row['id'] as String] = Map<String, dynamic>.from(row);
    if (loseAssetResponse) {
      loseAssetResponse = false;
      throw const EvidenceNetworkException('asset response lost');
    }
  }

  @override
  Future<Map<String, dynamic>?> getVariant(String id) async {
    variantReads++;
    return variants[id];
  }

  @override
  Future<void> insertVariant(Map<String, dynamic> row) async {
    if (variants.containsKey(row['id'])) {
      throw const EvidenceUploadException('duplicate variant');
    }
    variantInsertions++;
    variants[row['id'] as String] = Map<String, dynamic>.from(row);
    if (loseVariantResponse) {
      loseVariantResponse = false;
      throw const EvidenceNetworkException('variant response lost');
    }
  }

  @override
  Future<void> copy(String sourceBucket, String sourcePath,
      String destinationBucket, String destinationPath) async {
    copyAttempts++;
    if (pendingCopy != null) return pendingCopy!;
    if (failCopy) throw const EvidenceUploadException('copy not supported');
    final source = objects['$sourceBucket/$sourcePath'];
    if (source == null) throw const EvidenceUploadException('missing source');
    final key = '$destinationBucket/$destinationPath';
    if (objects.containsKey(key)) {
      throw const EvidenceUploadException('immutable destination');
    }
    objects[key] = Uint8List.fromList(source);
    if (loseCopyResponse) {
      throw const EvidenceNetworkException('copy response lost');
    }
  }

  @override
  Future<void> upload(String bucket, String path, Uint8List bytes) async {
    uploadAttempts++;
    if (failNextUploadBeforeStore) {
      failNextUploadBeforeStore = false;
      throw const EvidenceNetworkException('offline');
    }
    final key = '$bucket/$path';
    if (objects.containsKey(key)) {
      throw const EvidenceUploadException('object already exists');
    }
    objects[key] = Uint8List.fromList(bytes);
    if (loseNextUploadResponse) {
      loseNextUploadResponse = false;
      throw const EvidenceNetworkException('response lost');
    }
  }

  @override
  Future<Uint8List> download(String bucket, String path) async {
    downloadAttempts++;
    final bytes = objects['$bucket/$path'];
    if (bytes == null) throw const EvidenceUploadException('missing object');
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> link(
      String targetKind, String targetId, String variantId) async {
    links.add('$targetKind:$targetId:$variantId');
  }

  @override
  Future<Map<String, dynamic>?> requestVerification(String variantId) async {
    verificationRequests++;
    if (pendingVerification != null) return pendingVerification!;
    if (failVerificationRequest) {
      throw const EvidenceNetworkException('worker unavailable');
    }
    return verificationResponse ??
        {
          'processed': [
            {'state': 'waiting_prerequisite'}
          ],
        };
  }
}
