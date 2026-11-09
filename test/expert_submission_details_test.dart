import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cots_monitor/features/admin/screens/admin_record_details_screen.dart';
import 'package:cots_monitor/features/user/user_submission_details_page.dart';
import 'package:cots_monitor/features/user/user_record_details_page.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/models/submission_group.dart';
import 'submission_group_test.dart' as fixtures;

void main() {
  test(
      'pending photo needing site approval is waiting for Expert, not evidence',
      () {
    final group = SubmissionGroup.fromRecords([
      fixtures.photo('a', serverStatus: 'pending', assignedTo: 'Main Diver')
    ]).single;
    expect(group.reviewStatus, SubmissionReviewStatus.pendingReview);
    expect(group.statusLabel(), 'Requires Expert Validation');
    expect(group.cotsTally.confirmed, 0);
    expect(group.cotsTally.waiting, 1);
    expect(
        SubmissionGroup.fromRecords(
            [fixtures.photo('b', serverStatus: 'pending')]).single.reviewStatus,
        SubmissionReviewStatus.processing);
  });

  for (final layout in [(360.0, 1.0), (1400.0, 1.0), (360.0, 2.0)]) {
    testWidgets(
        'Expert can select a pending photo and access review controls at $layout',
        (tester) async {
      tester.view.physicalSize = Size(layout.$1, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final photos = [
        for (final id in ['a', 'b'])
          fixtures.photo(id, serverStatus: 'pending', assignedTo: 'Main Diver')
      ];
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(layout.$2)),
              child: child!),
          home: UserSubmissionDetailsPage(
            initialGroup: SubmissionGroup.fromRecords(photos).single,
            recordsStream: Stream<List<ScanRecordModel>>.value(photos),
            includePendingPhotos: false,
            reviewPhotos: true,
            reviewPanelBuilder: (photo, refresh) => AdminRecordDetailsScreen(
                key: ValueKey(photo.id),
                row: photo.toAdminTableRow(1),
                expertContext: true,
                reviewPanelOnly: true,
                onReviewSaved: refresh),
          )));
      await tester.pumpAndSettle();
      expect(find.byType(UserRecordDetailsPage), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('Requires Expert Validation'), findsOneWidget);
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>));
      dropdown.onChanged!('b');
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<UserRecordDetailsPage>(find.byType(UserRecordDetailsPage))
              .record
              .id,
          'b');
      await tester.ensureVisible(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(find.text('Reject'), findsOneWidget);
      final button = find.ancestor(
          of: find.text('Approve'),
          matching: find.byWidgetPredicate((w) => w is InkWell));
      expect(button, findsWidgets);
      expect(tester.widget<InkWell>(button.first).onTap, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }
}
