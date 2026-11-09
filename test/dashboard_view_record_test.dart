import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cots_monitor/features/admin/widgets/recent_submissions_table_card.dart';
import 'package:cots_monitor/features/admin/screens/admin_record_details_screen.dart';
import 'package:cots_monitor/features/user/user_submission_details_page.dart';
import 'package:cots_monitor/features/user/user_record_details_page.dart';
import 'package:cots_monitor/models/submission_group.dart';
import 'submission_group_test.dart' as fixtures;

void main() {
  testWidgets('dashboard eye opens the full batch beyond the five recent rows',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final records = [
      fixtures.photo('selected'),
      for (var i = 0; i < 4; i++) fixtures.photo('other-$i', batch: 'other-$i'),
      fixtures.photo('batch-peer')
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: RecentSubmissionsTableCard(
                    recordsStream: Stream.value(records))))));
    await tester.pumpAndSettle();
    expect(find.byTooltip('View'), findsNWidgets(5));
    await tester.tap(find.byTooltip('View').first);
    await tester.pumpAndSettle();
    final page = tester.widget<UserSubmissionDetailsPage>(
        find.byType(UserSubmissionDetailsPage));
    expect(page.initialGroup.photoCount, 2);
    expect(
        page.initialGroup.displayId,
        SubmissionGroup.fromRecords([records.first, records.last])
            .single
            .displayId);
    expect(page.reviewPhotos, isFalse);
    expect(page.useReadOnlyLayout, isTrue);
    expect(find.byType(UserRecordDetailsPage), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
    final selector = find.byType(DropdownButtonFormField<String>);
    expect(selector, findsOneWidget);
    tester
        .widget<DropdownButtonFormField<String>>(selector)
        .onChanged!(records.first.id);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<UserRecordDetailsPage>(find.byType(UserRecordDetailsPage))
            .record
            .id,
        records.first.id);
    expect(page.includePendingPhotos, isFalse);
    for (final photo in page.initialGroup.records) {
      final details = page.photoPageBuilder!(photo) as AdminRecordDetailsScreen;
      expect(details.viewOnly, isTrue);
      expect(details.row.documentId, photo.id);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard standalone eye opens original details view-only',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final photo = fixtures.photo('single', batch: '');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: RecentSubmissionsTableCard(
                    recordsStream: Stream.value([photo]))))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View'));
    await tester.pumpAndSettle();
    final details = tester.widget<AdminRecordDetailsScreen>(
        find.byType(AdminRecordDetailsScreen));
    expect(details.viewOnly, isTrue);
    expect(details.row.documentId, photo.id);
    expect(tester.takeException(), isNull);
  });
}
