import 'package:cots_monitor/features/user/records_page.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/models/user_model.dart';
import 'package:cots_monitor/providers/auth_provider.dart';
import 'package:cots_monitor/services/offline_submission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Record extends ScanRecordModel {
  _Record(String id, this.label)
      : super(
            id: id,
            uid: 'diver',
            submittedBy: 'Diver',
            imageName: '',
            imagePath: '',
            activityType: 'detection_only',
            aiDetectedCount: 1,
            confidence: .9,
            captureSource: 'camera',
            zone: 'Site',
            notes: '',
            submittedAt: DateTime(2026, 11, 8),
            storedDisplayRecordId: id);
  final String label;
  @override
  String get userStatusLabel => label;
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

void main() {
  for (final width in [360.0, 1200.0]) {
    testWidgets(
        'summary filters combine with search and toggle back to all ($width)',
        (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final records = [
        _Record('P1', 'Processing evidence'),
        _Record('P2', 'Submitted'),
        _Record('P3', 'Pending Validation'),
        _Record('P4', 'Pending synchronization'),
        _Record('A1', 'Accepted'),
        _Record('A2', 'Automatically Accepted'),
        _Record('A3', 'Partially accepted'),
        _Record('R1', 'Under Review'),
        _Record('R2', 'Requires Expert Validation'),
        _Record('X1', 'Retake Photo'),
        _Record('X2', 'Needs Correction'),
        _Record('X3', 'Completed Monitoring'),
      ];
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
            ChangeNotifierProvider<OfflineSubmissionService>(
                create: (_) =>
                    OfflineSubmissionService(enableAutomaticSync: false)),
          ],
          child: MaterialApp(
              home: RecordsPage(recordsStream: Stream.value(records)))));
      await tester.pumpAndSettle();
      Finder card(String group) => find.byKey(ValueKey('records-card-$group'));
      void count(String group, String number) => expect(
          find.descendant(of: card(group), matching: find.text(number)),
          findsOneWidget);
      Future<void> tapCard(String group) async {
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        await tester.tap(card(group));
        await tester.pumpAndSettle();
      }

      count('all', '12');
      count('accepted', '3');
      count('review', '2');
      count('processing', '4');
      expect(find.text('Filters'), findsNothing);
      expect(find.byIcon(Icons.filter_list), findsNothing);

      await tester.scrollUntilVisible(find.text('Load more'), 400,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Load more'));
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('X3'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('X3'), findsOneWidget);
      await tapCard('processing');
      for (final id in ['P1', 'P2', 'P3', 'P4']) {
        expect(find.text(id), findsOneWidget);
      }
      for (final id in ['A1', 'R1', 'X1']) {
        expect(find.text(id), findsNothing);
      }
      final material = tester.widget<Material>(find
          .descendant(of: card('processing'), matching: find.byType(Material))
          .first);
      expect((material.shape! as RoundedRectangleBorder).side.width, 2);
      await tapCard('processing');
      expect(find.text('A1'), findsOneWidget);
      expect(find.text('X3'), findsNothing); // Back to the first eight.

      await tapCard('accepted');
      expect(find.text('A3'), findsOneWidget);
      expect(find.text('P1'), findsNothing);
      await tester.enterText(find.byType(TextField), 'A2');
      await tester.pumpAndSettle();
      expect(find.text('A1'), findsNothing);
      expect(find.text('Automatically Accepted'), findsOneWidget);
      await tapCard('review');
      expect(find.text('No matching records'), findsOneWidget);
      await tester.ensureVisible(find.text('Clear search and filters'));
      await tester.tap(find.text('Clear search and filters'));
      await tester.pumpAndSettle();
      await tapCard('review');
      expect(find.text('R1'), findsOneWidget);
      expect(find.text('R2'), findsOneWidget);
      expect(find.text('P1'), findsNothing);
      await tapCard('all');
      expect(find.text('P1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
