import 'dart:async';
import 'package:cots_monitor/features/user/follow_up_page.dart';
import 'package:cots_monitor/models/capture_model.dart';
import 'package:cots_monitor/models/follow_up_monitoring_model.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/models/user_model.dart';
import 'package:cots_monitor/providers/auth_provider.dart';
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
  void refresh() => notifyListeners();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
      'monthly sources start together and stay subscribed through rebuilds',
      (tester) async {
    final auth = _Auth();
    final listens = <String>[];
    final cancels = <String>[];
    StreamController<List<T>> source<T>(String name) =>
        StreamController<List<T>>(
            onListen: () => listens.add(name),
            onCancel: () => cancels.add(name));
    final captures = source<CaptureModel>('captures');
    final assignments = source<FollowUpAssignmentModel>('assignments');
    final surveys = source<FollowUpSurveyModel>('surveys');
    final records = source<ScanRecordModel>('records');
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            home: FollowUpPage(
                capturesStream: captures.stream,
                assignmentsStream: assignments.stream,
                surveysStream: surveys.stream,
                recordsStream: records.stream))));
    await tester.pump();
    expect(listens, ['captures', 'assignments', 'surveys', 'records']);
    // A slow capture read does not delay starting the other reads.
    assignments.add([]);
    surveys.add([]);
    records.add([]);
    await tester.pump();
    auth.refresh();
    await tester.pump();
    expect(listens.length, 4);
    expect(cancels, isEmpty);
    captures.add([]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Monthly reef follow-up'), findsOneWidget);
    expect(find.textContaining('Checking previous accepted detections'),
        findsNothing);
    auth.refresh();
    records.add([]);
    await tester.pump();
    expect(listens.length, 4);
    expect(cancels, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(cancels.toSet(), {'captures', 'assignments', 'surveys', 'records'});
    unawaited(captures.close());
    unawaited(assignments.close());
    unawaited(surveys.close());
    unawaited(records.close());
    await tester.pump();
    auth.dispose();
  });

  testWidgets(
      'a failed source shows its error without waiting for slow sources',
      (tester) async {
    final auth = _Auth();
    final captures = StreamController<List<CaptureModel>>();
    final assignments = StreamController<List<FollowUpAssignmentModel>>();
    final surveys = StreamController<List<FollowUpSurveyModel>>();
    final records = StreamController<List<ScanRecordModel>>();
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            home: FollowUpPage(
                capturesStream: captures.stream,
                assignmentsStream: assignments.stream,
                surveysStream: surveys.stream,
                recordsStream: records.stream))));
    surveys.addError(StateError('offline'));
    await tester.pump();
    expect(find.text('Could not load monitoring history.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(captures.close());
    unawaited(assignments.close());
    unawaited(surveys.close());
    unawaited(records.close());
    await tester.pump();
    auth.dispose();
  });
}
