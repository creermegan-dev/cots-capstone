import 'dart:typed_data';

import 'package:cots_monitor/services/supabase_evidence_service.dart';
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

class _FakeEvidenceGateway implements EvidenceGateway {
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
  Map<String, dynamic>? verificationResponse;

  @override
  Future<Map<String, dynamic>?> getAsset(String id) async => assets[id];

  @override
  Future<void> insertAsset(Map<String, dynamic> row) async {
    assetInsertions++;
    assets[row['id'] as String] = Map<String, dynamic>.from(row);
  }

  @override
  Future<Map<String, dynamic>?> getVariant(String id) async => variants[id];

  @override
  Future<void> insertVariant(Map<String, dynamic> row) async {
    variantInsertions++;
    variants[row['id'] as String] = Map<String, dynamic>.from(row);
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
