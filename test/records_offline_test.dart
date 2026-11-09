import 'dart:async';
import 'dart:io';

import 'package:cots_monitor/features/user/records_page.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/models/user_model.dart';
import 'package:cots_monitor/providers/auth_provider.dart';
import 'package:cots_monitor/services/offline_submission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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
  @override
  int get pendingCount => 1;
  @override
  List<PendingSubmissionSummary> get pendingSubmissions => [
        PendingSubmissionSummary(
            id: 'pending-1',
            name: 'my-offline-photo.jpg',
            failureReason:
                'Upload not permitted. Ask the Expert to check your Diver verification.',
            createdAt: DateTime(2026, 11, 5, 20)),
      ];
}

void main() {
  testWidgets(
      'Records keeps local pending photos accessible without server data',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final stream = StreamController<List<ScanRecordModel>>();
    addTearDown(stream.close);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
      ChangeNotifierProvider<OfflineSubmissionService>(create: (_) => _Queue()),
    ], child: MaterialApp(home: RecordsPage(recordsStream: stream.stream))));
    await tester.pump();
    expect(find.text('1 submission pending synchronization'), findsOneWidget);
    stream.addError(const SocketException('private-host/raw-query'));
    await tester.pumpAndSettle();
    expect(find.textContaining('private-host'), findsNothing);
    expect(find.text('Saved records unavailable while disconnected'),
        findsOneWidget);
    await tester.ensureVisible(find.text('my-offline-photo.jpg'));
    expect(find.text('my-offline-photo.jpg'), findsOneWidget);
    expect(find.textContaining('Ask the Expert'), findsOneWidget);
    expect(find.textContaining('Pending synchronization'), findsOneWidget);
    expect(tester.takeException(), isNull);
    stream.add(const []);
    await tester.pumpAndSettle();
    expect(find.text('Saved records unavailable while disconnected'),
        findsNothing);
    expect(find.text('my-offline-photo.jpg'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
