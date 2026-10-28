import 'dart:io';
import 'dart:typed_data';

import 'package:cots_monitor/models/activity_type.dart';
import 'package:cots_monitor/models/cots_detection_result.dart';
import 'package:cots_monitor/services/offline_submission_service.dart';
import 'package:flutter_test/flutter_test.dart';

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

    online = true;
    final restarted = OfflineSubmissionService(
      directoryProvider: () async => temporaryDirectory,
      recordUploader: uploader,
      enableAutomaticSync: false,
    );
    await restarted.initialize();
    await restarted.setActiveUser('diver-a');
    await restarted.syncPending();

    expect(restarted.pendingCount, 0);
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

    await service.setActiveUser('diver-a');
    await service.syncPending();
    expect(successfulUploads, 1);
    expect(service.pendingCount, 0);
  });

  test('invalid submissions are not retained as retryable network work',
      () async {
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
    expect(service.pendingCount, 0);
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
    imageBytes: Uint8List.fromList(List<int>.generate(32, (index) => index)),
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
