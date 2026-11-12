import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cots_monitor/features/user/records_page.dart';
import 'package:cots_monitor/models/cots_detection_result.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/models/user_model.dart';
import 'package:cots_monitor/providers/auth_provider.dart';
import 'package:cots_monitor/services/no_cots_survey_service.dart';
import 'package:cots_monitor/services/offline_submission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const reason = 'COTS have already been reported at this site for this month. '
    'A no-COTS survey cannot be submitted.';
const params = {'p_area_code': 'S4', 'p_surveyed_at': '2026-11-11T01:00:00Z'};

Future<void> refuse(OfflineSubmissionService queue, {String id = 'refused'}) =>
    expectLater(queue.submitNoCotsSurvey(uid: 'diver', id: id, params: params),
        throwsA(isA<NoCotsSurveyConflict>()));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('owner removes refused draft while pending photo remains safe',
      () async {
    final directory = await Directory.systemTemp.createTemp('remove_survey_');
    final queue = OfflineSubmissionService(
        directoryProvider: () async => directory,
        enableAutomaticSync: false,
        noCotsUploader: (_) async => throw const NoCotsSurveyConflict(reason),
        recordUploader: (_, __) async =>
            throw const SocketException('offline'));
    try {
      await queue.initialize();
      await refuse(queue);
      await queue.submitRecord(
          uid: 'diver',
          submittedBy: 'Diver',
          imageName: 'photo.jpg',
          imageBytes: Uint8List.fromList([1, 2, 3]),
          activityType: 'detection_only',
          detection:
              const CotsDetectionResult(count: 1, confidence: .9, boxes: []),
          latitude: 7,
          longitude: 125.7,
          dateTaken: DateTime.utc(2026, 11, 11),
          imageWidth: 10,
          imageHeight: 10,
          notes: '',
          depth: null,
          confirmedRemovedQuantity: null,
          measurementReferenceVisible: null,
          removalMethod: null,
          sizeEstimate: null,
          submissionId: 'photo');
      expect(queue.pendingCount, 1);
      final photo =
          queue.pendingSubmissions.singleWhere((s) => s.record != null);
      final image = File(photo.record!.imagePath);
      expect(await queue.removeRefusedNoCotsDraft('photo'), isFalse);
      expect(await image.readAsBytes(), [1, 2, 3]);
      expect(await queue.removeRefusedNoCotsDraft('refused'), isTrue);
      expect(await queue.removeRefusedNoCotsDraft('refused'), isFalse);
      expect(queue.pendingCount, 1);
      expect(queue.pendingSubmissions.single.id, 'photo');
      expect(await image.readAsBytes(), [1, 2, 3]);
    } finally {
      queue.dispose();
      await directory.delete(recursive: true);
    }
  });

  test('another account cannot remove the refused draft', () async {
    final directory = await Directory.systemTemp.createTemp('owner_survey_');
    final queue = OfflineSubmissionService(
        directoryProvider: () async => directory,
        enableAutomaticSync: false,
        noCotsUploader: (_) async => throw const NoCotsSurveyConflict(reason));
    try {
      await queue.initialize();
      await refuse(queue);
      await queue.setActiveUser('another');
      expect(await queue.removeRefusedNoCotsDraft('refused'), isFalse);
      await queue.setActiveUser('diver');
      expect(queue.pendingSubmissions.single.id, 'refused');
      expect(await queue.removeRefusedNoCotsDraft('refused'), isTrue);
    } finally {
      queue.dispose();
      await directory.delete(recursive: true);
    }
  });

  test('network-pending and already uploaded surveys cannot be removed',
      () async {
    final directory = await Directory.systemTemp.createTemp('pending_survey_');
    var online = false;
    final queue = OfflineSubmissionService(
        directoryProvider: () async => directory,
        enableAutomaticSync: false,
        noCotsUploader: (_) async {
          if (!online) throw const SocketException('offline');
        });
    try {
      await queue.initialize();
      expect(
          await queue.submitNoCotsSurvey(
              uid: 'diver', id: 'valid', params: params),
          isTrue);
      expect(await queue.removeRefusedNoCotsDraft('valid'), isFalse);
      expect(queue.pendingCount, 1);
      online = true;
      await queue.syncPending();
      expect(queue.pendingSubmissions, isEmpty);
      expect(await queue.removeRefusedNoCotsDraft('valid'), isFalse);
    } finally {
      queue.dispose();
      await directory.delete(recursive: true);
    }
  });

  test('a draft being submitted cannot be removed', () async {
    final directory = await Directory.systemTemp.createTemp('active_survey_');
    final started = Completer<void>();
    final finish = Completer<void>();
    final queue = OfflineSubmissionService(
        directoryProvider: () async => directory,
        enableAutomaticSync: false,
        noCotsUploader: (_) async {
          started.complete();
          await finish.future;
          throw const NoCotsSurveyConflict(reason);
        });
    try {
      await queue.initialize();
      final submission = refuse(queue);
      await started.future;
      expect(await queue.removeRefusedNoCotsDraft('refused'), isFalse);
      finish.complete();
      await submission;
      expect(await queue.removeRefusedNoCotsDraft('refused'), isTrue);
    } finally {
      queue.dispose();
      await directory.delete(recursive: true);
    }
  });

  for (final width in [360.0, 1200.0]) {
    testWidgets('refused draft has confirmed removal only ($width)',
        (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = (await tester
          .runAsync(() => Directory.systemTemp.createTemp('survey_ui_')))!;
      final queue = OfflineSubmissionService(
          directoryProvider: () async => directory,
          enableAutomaticSync: false,
          noCotsUploader: (_) async =>
              throw const NoCotsSurveyConflict(reason));
      await tester.runAsync(() async {
        await queue.initialize();
        await refuse(queue);
      });
      try {
        await tester.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
              ChangeNotifierProvider<OfflineSubmissionService>.value(
                  value: queue),
            ],
            child: MaterialApp(
                home: RecordsPage(
              recordsStream: Stream.value(const <ScanRecordModel>[]),
              surveyLoader: ({required mineOnly}) async => [
                {
                  'id': 'server-survey',
                  'area_name': 'Uploaded site',
                  'submitted_at': '2026-11-10T01:00:00Z',
                }
              ],
            ))));
        await tester.pumpAndSettle();
        expect(find.text('Not submitted'), findsOneWidget);
        expect(find.text('Remove saved draft'), findsOneWidget);
        expect(find.text('Survey · Uploaded site'), findsOneWidget);
        expect(find.textContaining('pending synchronization'), findsNothing);
        final remove =
            find.byKey(const ValueKey('remove-survey-draft-refused'));
        await tester.ensureVisible(remove);
        await tester.tap(remove);
        await tester.pumpAndSettle();
        expect(find.text('Remove saved draft?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(queue.pendingSubmissions.single.id, 'refused');
        await tester.tap(remove);
        await tester.pumpAndSettle();
        await tester
            .tap(find.byKey(const ValueKey('confirm-remove-survey-draft')));
        await tester.pumpAndSettle();
        for (var i = 0; i < 50 && queue.pendingSubmissions.isNotEmpty; i++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(queue.pendingSubmissions, isEmpty);
        expect(find.text('Remove saved draft'), findsNothing);
        expect(find.text('Survey · Uploaded site'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        queue.dispose();
        await tester.runAsync(() => directory.delete(recursive: true));
      }
    });
  }
}

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  bool get usesSupabase => true;
  @override
  UserModel get userModel => const UserModel(
      uid: 'diver',
      fullName: 'Diver',
      email: '',
      phoneNumber: '',
      role: 'Diver',
      organization: '',
      assignedArea: '',
      createdAt: null,
      profileImage: '',
      isActive: true);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
