import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:cots_monitor/models/activity_type.dart';
import 'package:cots_monitor/models/cots_detection_result.dart';
import 'package:cots_monitor/services/offline_submission_service.dart';
import 'package:cots_monitor/services/supabase_evidence_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('cots_offline_');
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('background sync cannot delete a photo while Submit saves progress',
      () async {
    final started = Completer<void>();
    final release = Completer<void>();
    var uploads = 0;
    final service = OfflineSubmissionService(
      directoryProvider: () async => temporaryDirectory,
      enableAutomaticSync: false,
      recordUploader: (task, image) async {
        uploads++;
        if (uploads == 1) {
          started.complete();
          await release.future;
          // Reproduce the evidence progress write that failed on the phone.
          await File('${image.parent.path}/metadata.json')
              .writeAsString('{"progress":"linked"}', flush: true);
        }
      },
    );
    await service.initialize();
    final foreground = _submit(service, id: 'batch-photo-1', uid: 'diver-a');
    await started.future;
    await service.syncPending();
    final uploadsDuringForeground = uploads;
    release.complete();
    final result = await foreground;
    expect(result.isPending, isFalse);
    expect(uploadsDuringForeground, 1);
    expect(service.pendingCount, 0);
    service.dispose();
  });

  test('offline submission survives restart and uploads later', () async {
    var online = false;
    var uploads = 0;
    Future<void> uploader(Map<String, dynamic> task, File image) async {
      uploads++;
      expect(await image.exists(), isTrue);
      if (!online) throw const SocketException('offline');
    }

    final first = OfflineSubmissionService(
      directoryProvider: () async => temporaryDirectory,
      recordUploader: uploader,
      enableAutomaticSync: false,
    );
    await first.initialize();
    final result = await _submit(first, id: 'record-1', uid: 'diver-a');

    expect(result.isPending, isTrue);
    expect(first.pendingCount, 1);
    expect(first.pendingSubmissions.single.name, 'cots.jpg');

    final restarted = OfflineSubmissionService(
      directoryProvider: () async => temporaryDirectory,
      recordUploader: uploader,
      enableAutomaticSync: false,
    );
    await restarted.initialize();
    await restarted.setActiveUser('diver-a');
    expect(restarted.pendingSubmissions.single.id, 'record-1');
    online = true;
    await restarted.syncPending();

    expect(restarted.pendingCount, 0);
    expect(restarted.pendingSubmissions, isEmpty);
    expect(uploads, greaterThanOrEqualTo(2));
  });

  test('pending submissions only synchronize for their owner', () async {
    var online = false;
    var successfulUploads = 0;
    final service = OfflineSubmissionService(
      directoryProvider: () async => temporaryDirectory,
      recordUploader: (task, image) async {
        if (!online) throw const SocketException('offline');
        successfulUploads++;
      },
      enableAutomaticSync: false,
    );
    await service.initialize();
    await _submit(service, id: 'record-2', uid: 'diver-a');

    online = true;
    await service.setActiveUser('diver-b');
    await service.syncPending();
    expect(successfulUploads, 0);
    expect(service.pendingCount, 0);
    expect(service.pendingSubmissions, isEmpty);

    await service.setActiveUser('diver-a');
    await service.syncPending();
    expect(successfulUploads, 1);
    expect(service.pendingCount, 0);
  });

  test('invalid submissions remain retained for manual diagnosis', () async {
    final service = OfflineSubmissionService(
      directoryProvider: () async => temporaryDirectory,
      recordUploader: (task, image) async => throw StateError('invalid'),
      enableAutomaticSync: false,
    );
    await service.initialize();

    await expectLater(
      _submit(service, id: 'record-3', uid: 'diver-a'),
      throwsStateError,
    );
    expect(service.pendingCount, 1);
  });

  test('authorization and upload failures remain queued with distinct states',
      () async {
    final authorization = OfflineSubmissionService(
      directoryProvider: () async => temporaryDirectory,
      recordUploader: (task, image) async =>
          throw const EvidenceAuthorizationException('denied'),
      enableAutomaticSync: false,
    );
    await authorization.initialize();
    final blocked =
        await _submit(authorization, id: 'record-4', uid: 'diver-a');
    expect(blocked.state, OfflineSubmitState.authorizationBlocked);
    expect(authorization.pendingCount, 1);
    expect(authorization.pendingSubmissions.single.failureReason,
        contains('Ask the Expert to check your Diver verification'));
    final restarted = OfflineSubmissionService(
      directoryProvider: () async => temporaryDirectory,
      enableAutomaticSync: false,
      recordUploader: (_, image) async =>
          throw const EvidenceAuthorizationException('private-server-details'),
    );
    await restarted.initialize();
    await restarted.setActiveUser('diver-a');
    expect(restarted.pendingSubmissions.single.failureReason,
        authorization.pendingSubmissions.single.failureReason);
    expect(restarted.pendingSubmissions.single.failureReason,
        isNot(contains('private-server-details')));
    restarted.dispose();

    await temporaryDirectory.delete(recursive: true);
    await temporaryDirectory.create(recursive: true);
    final upload = OfflineSubmissionService(
      directoryProvider: () async => temporaryDirectory,
      recordUploader: (task, image) async =>
          throw const EvidenceUploadException('failed'),
      enableAutomaticSync: false,
    );
    await upload.initialize();
    final pending = await _submit(upload, id: 'record-5', uid: 'diver-a');
    expect(pending.state, OfflineSubmitState.uploadPending);
    expect(upload.pendingCount, 1);
  });
}

Future<OfflineSubmitResult> _submit(
  OfflineSubmissionService service, {
  required String id,
  required String uid,
}) {
  return service.submitRecord(
    uid: uid,
    submittedBy: 'Test Diver',
    imageName: 'cots.jpg',
    imageBytes: Uint8List.fromList(
      img.encodePng(img.Image(width: 2, height: 2)),
    ),
    activityType: CotsActivityType.removalActivity,
    detection: const CotsDetectionResult(
      count: 1,
      confidence: 0.82,
      boxes: [],
    ),
    latitude: 7.1,
    longitude: 125.6,
    dateTaken: DateTime.utc(2026, 10, 28),
    imageWidth: 640,
    imageHeight: 640,
    notes: 'Offline test',
    depth: 4,
    confirmedRemovedQuantity: 1,
    measurementReferenceVisible: null,
    removalMethod: 'Manual Removal',
    sizeEstimate: null,
    submissionId: id,
  );
}
