import 'dart:async';

import 'package:cots_monitor/features/user/records_page.dart';
import 'package:cots_monitor/features/user/user_submission_details_page.dart';
import 'package:cots_monitor/models/capture_model.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/models/submission_group.dart';
import 'package:cots_monitor/models/user_model.dart';
import 'package:cots_monitor/providers/auth_provider.dart';
import 'package:cots_monitor/services/offline_submission_service.dart';
import 'package:cots_monitor/services/supabase_record_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

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

class _Queue extends OfflineSubmissionService {
  _Queue() : super(enableAutomaticSync: false);
  List<PendingSubmissionSummary> tasks = [];
  void replace(List<PendingSubmissionSummary> value) {
    tasks = value;
    notifyListeners();
  }

  @override
  int get pendingCount => tasks.length;
  @override
  List<PendingSubmissionSummary> get pendingSubmissions => tasks;
}

ScanRecordModel _photo(String id,
        {String site = 'S1',
        int count = 1,
        String batch = 'batch',
        double confidence = .9,
        bool accepted = false}) =>
    ScanRecordModel.fromCapture(CaptureModel(
      id: id,
      uid: 'diver',
      submittedBy: 'Diver',
      imageName: '$id.jpg',
      aiDetectedCount: count,
      confidence: confidence,
      captureSource: 'camera',
      zone: site,
      notes: '',
      submittedAt: DateTime.utc(2026, 11, 5, 13),
      dateTaken: DateTime.utc(2026, 11, 5, 12),
      latitude: 7.1,
      longitude: 125.7,
      encounterId: batch,
      monitoringAreaId: site,
      locationSource: 'exif',
      timeSource: 'exif',
      serverStatus: 'finalized',
      adminConfirmed: accepted,
    ));

Widget _app(Widget page, _Queue queue) => MultiProvider(providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
      ChangeNotifierProvider<OfflineSubmissionService>.value(value: queue),
    ], child: MaterialApp(home: page));

void main() {
  testWidgets(
      'one-photo submissions open full record details without an extra step',
      (tester) async {
    final photo = _photo('single');
    final queue = _Queue();
    addTearDown(queue.dispose);
    await tester.pumpWidget(_app(
        UserSubmissionDetailsPage(
            initialGroup: SubmissionGroup.fromRecords([photo]).single,
            recordsStream: Stream.value([photo])),
        queue));
    await tester.pumpAndSettle();
    expect(find.text('Record Details'), findsOneWidget);
    expect(find.text('Detection Image'), findsOneWidget);
    expect(find.text('Detection Results'), findsOneWidget);
    expect(find.text('Information'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('View photo details'), findsNothing);
    expect(find.text(photo.displayRecordId), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final width in [390.0, 1200.0]) {
    testWidgets(
        'Records groups batch/site, searches child names, and opens photo details at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final photos = [
        _photo('a', count: 2),
        _photo('b'),
        _photo('c', site: 'S2'),
        _photo('old', batch: '')
      ];
      final group = SubmissionGroup.fromRecords(photos)
          .firstWhere((g) => g.photoCount == 2);
      final queue = _Queue();
      addTearDown(queue.dispose);
      await tester.pumpWidget(
          _app(RecordsPage(recordsStream: Stream.value(photos)), queue));
      await tester.pumpAndSettle();
      expect(find.text('2 photos · 3 COTS detected'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'b.jpg');
      await tester.pumpAndSettle();
      expect(find.text(group.displayId), findsOneWidget);
      await tester.ensureVisible(find.text(group.displayId));
      await tester.tap(find.text(group.displayId));
      await tester.pumpAndSettle();
      expect(find.text('Record Details'), findsOneWidget);
      expect(find.text('Detection Image'), findsOneWidget);
      expect(find.text('View photo details'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.textContaining('b.jpg'), findsWidgets);
      await tester.tap(find.textContaining('b.jpg').last);
      await tester.pumpAndSettle();
      expect(find.text('Photo file'), findsOneWidget);
      expect(find.text('c.jpg'), findsNothing);
      expect(find.text('old.jpg'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'partial synchronization stays in one row without duplicate photo counts',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PendingSubmissionSummary pending(String id) =>
        PendingSubmissionSummary.fromTask({
          'version': 2,
          'kind': 'record',
          'id': id,
          'uid': 'diver',
          'submitted_by': 'Diver',
          'image_name': '$id.jpg',
          'encounter_id': 'local-batch',
          'monitoring_area_id': 'S1',
          'created_at': '2026-11-05T13:00:00Z',
          'detection': {'count': 1, 'confidence': .9, 'boxes': []},
        }, 'test-queue');
    final a = pending('local-a'), b = pending('local-b');
    final batch = SupabaseRecordService.stableUuid('encounter', 'local-batch');
    final serverA = _photo(a.record!.id, batch: batch);
    final serverB = _photo(b.record!.id, batch: batch);
    final id =
        SubmissionGroup.fromRecords([a.record!, b.record!]).single.displayId;
    final queue = _Queue()..tasks = [a, b];
    addTearDown(queue.dispose);
    final stream = StreamController<List<ScanRecordModel>>();
    addTearDown(stream.close);
    await tester
        .pumpWidget(_app(RecordsPage(recordsStream: stream.stream), queue));
    stream.add([]);
    await tester.pumpAndSettle();
    expect(find.text('1 submission pending synchronization'), findsOneWidget);
    expect(find.text('2 photos · 2 COTS detected'), findsOneWidget);
    expect(find.text(id), findsOneWidget);
    stream.add([serverA]);
    queue.replace([b]);
    await tester.pumpAndSettle();
    expect(find.text('2 photos · 2 COTS detected'), findsOneWidget);
    expect(find.text(id), findsOneWidget);
    stream.add([serverA, serverB]);
    queue.replace([]);
    await tester.pumpAndSettle();
    expect(find.text('2 photos · 2 COTS detected'), findsOneWidget);
    final recordCard =
        find.ancestor(of: find.text(id), matching: find.byType(Material)).first;
    expect(find.descendant(of: recordCard, matching: find.text('Accepted')),
        findsOneWidget);
    expect(find.text(id), findsOneWidget);
    expect(find.text('Pending synchronization'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('group detail status stays pending while one photo needs review',
      (tester) async {
    final a = _photo('a'), b = _photo('b', confidence: .6);
    final queue = _Queue();
    addTearDown(queue.dispose);
    final stream = StreamController<List<ScanRecordModel>>();
    addTearDown(stream.close);
    await tester.pumpWidget(_app(
        UserSubmissionDetailsPage(
          initialGroup: SubmissionGroup.fromRecords([a, b]).single,
          recordsStream: stream.stream,
        ),
        queue));
    stream.add([a, b]);
    await tester.pumpAndSettle();
    expect(find.text('Requires Expert Validation'), findsOneWidget);
    expect(find.text('Confirmed: 1 · Waiting: 1 · Not accepted: 0'),
        findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('b.jpg').last);
    await tester.pumpAndSettle();
    expect(find.text('60% avg'), findsOneWidget);
    expect(find.text(b.formattedCoordinates), findsOneWidget);
    expect(find.text('Photo GPS'), findsOneWidget);
    expect(
        find.textContaining(
            DateFormat('MMM d, yyyy h:mm a').format(b.dateTaken!.toLocal())),
        findsOneWidget);
    stream.add([a, _photo('b', confidence: .6, accepted: true)]);
    await tester.pumpAndSettle();
    expect(find.text('Accepted'), findsOneWidget);
    expect(find.text('Confirmed: 2 · Waiting: 0 · Not accepted: 0'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
