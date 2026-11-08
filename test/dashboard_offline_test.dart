import 'dart:async';
import 'dart:io';

import 'package:cots_monitor/features/user/dashboard_screen.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/models/activity_type.dart';
import 'package:cots_monitor/models/record_collection.dart';
import 'package:cots_monitor/models/user_model.dart';
import 'package:cots_monitor/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  UserModel? get userModel => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final width in [320.0, 1000.0]) {
    testWidgets('offline dashboard is safe and recovers at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final stream = StreamController<List<ScanRecordModel>>();
      addTearDown(stream.close);
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>(
        create: (_) => _Auth(),
        child: MaterialApp(home: DashboardScreen(recordsStream: stream.stream)),
      ));
      stream.addError(const SocketException('secret-host.example/raw-query'));
      await tester.pumpAndSettle();
      expect(find.text('Offline mode'), findsOneWidget);
      expect(find.textContaining('secret-host'), findsNothing);
      expect(find.text('Key Metrics'), findsNothing);
      expect(find.text('Retry dashboard'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final submitted = DateTime.utc(2026, 11, 5, 13, 9);
      stream.add([
        ScanRecordModel(
          id: 'test-record',
          uid: 'diver',
          submittedBy: 'Diver',
          imageName: '',
          imagePath: '',
          activityType: CotsActivityType.detectionOnly,
          aiDetectedCount: 1,
          confidence: .9,
          captureSource: CaptureSource.goProUnderwaterImage,
          zone: 'Test site',
          notes: '',
          submittedAt: submitted,
          recordCollection: RecordCollection.captures,
        )
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Offline mode'), findsNothing);
      expect(find.text('Key Metrics'), findsOneWidget);
      expect(
          find.text(
              'Latest record ${DateFormat('MMM d, h:mm a').format(submitted.toLocal())}'),
          findsOneWidget);
      await tester.scrollUntilVisible(
          find.text(
              DateFormat('MMM d, yyyy · h:mm a').format(submitted.toLocal())),
          200,
          scrollable: find.byType(Scrollable).first);
      expect(
          find.text(
              DateFormat('MMM d, yyyy · h:mm a').format(submitted.toLocal())),
          findsOneWidget);
      stream.addError(const SocketException('offline again'));
      await tester.pumpAndSettle();
      expect(find.text('Offline mode'), findsOneWidget);
      expect(find.textContaining('last loaded dashboard'), findsOneWidget);
      expect(find.text('Key Metrics'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
