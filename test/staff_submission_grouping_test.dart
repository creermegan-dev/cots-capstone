import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cots_monitor/models/staff_submission_rows.dart';
import 'package:cots_monitor/models/submission_group.dart';
import 'package:cots_monitor/models/monitoring_analytics.dart';
import 'package:cots_monitor/services/admin_report_export_service.dart';
import 'package:cots_monitor/features/admin/screens/admin_records_submissions_screen.dart';
import 'package:cots_monitor/features/user/user_submission_details_page.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/features/admin/models/admin_record_table_row.dart';
import 'package:cots_monitor/features/expert/models/expert_action_item.dart';
import 'package:cots_monitor/models/zone_directory_summary.dart';
import 'package:cots_monitor/features/user/cots_map_page.dart';
import 'submission_group_test.dart' as fixtures;
import 'support/map_test_data.dart';

void main() {
  setUpAll(loadTestMap);
  testWidgets('staff table lists one submission and finds an original photo ID',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final photos = [fixtures.photo('a'), fixtures.photo('b')];
    final group = SubmissionGroup.fromRecords(photos).single;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdminRecordsSubmissionsScreen(
                viewOnly: true,
                recordsStream: Stream.value(
                    [for (final photo in photos) photo.toAdminTableRow(1)])))));
    await tester.pumpAndSettle();
    expect(find.text(group.displayId), findsOneWidget);
    expect(find.text('2 photos'), findsOneWidget);
    await tester.enterText(
        find.byType(TextField).first, photos.last.displayRecordId);
    await tester.pumpAndSettle();
    expect(find.text(group.displayId), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'staff details opens original photo and follows pending-to-accepted updates without a local queue',
      (tester) async {
    final a = fixtures.photo('a', confidence: .6), b = fixtures.photo('b');
    final stream = StreamController<List<ScanRecordModel>>.broadcast();
    addTearDown(stream.close);
    String? opened;
    await tester.pumpWidget(MaterialApp(
        home: UserSubmissionDetailsPage(
            initialGroup: SubmissionGroup.fromRecords([a, b]).single,
            recordsStream: stream.stream,
            includePendingPhotos: false,
            reviewPhotos: true,
            onPhotoOpen: (photo) => opened = photo.id,
            photoPageBuilder: (photo) => Scaffold(
                appBar: AppBar(), body: Text('Original photo ${photo.id}')))));
    await tester.pumpAndSettle();
    expect(find.text('Requires Expert Validation'), findsOneWidget);
    await tester.tap(find.text('a.jpg'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Review photo').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review photo').first);
    await tester.pumpAndSettle();
    expect(opened, 'a');
    expect(find.text('Original photo a'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    stream.add([fixtures.photo('a', confidence: .6, accepted: true), b]);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(find.text('Accepted'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
      'staff grouping preserves original identities and counts each photo once',
      () {
    final a = fixtures.photo('a', count: 2);
    final b = fixtures.photo('b', confidence: .6);
    final expected = SubmissionGroup.fromRecords([a, b]).single;
    final row = StaffSubmissionRows.group(
            [a.toAdminTableRow(1), b.toAdminTableRow(2), a.toAdminTableRow(1)])
        .single;
    expect(row.recordId, expected.displayId);
    expect(row.documentId, isEmpty);
    expect(row.displayAiCount, 3);
    expect(row.displayStatusLabel, 'Under Review');
    expect(row.cotsTally.confirmed, 2);
    expect(row.cotsTally.waiting, 1);
    final restored = StaffSubmissionRows.groupFor(row);
    expect(restored.records.map((photo) => photo.id), ['a', 'b']);
    expect(restored.records.first.latitude, a.latitude);
    expect(restored.records.last.confidence, b.confidence);
    expect(restored.records.first.dateTaken, a.dateTaken);
    expect(StaffSubmissionRows.group([row]).single.recordId, row.recordId);
    final analytics = MonitoringAnalytics.fromRecords([a, b]);
    expect(analytics.submissionCount, 1);
    expect(analytics.captures.length, 2);
    expect(analytics.totalCots, 3);
    expect(analytics.pendingSubmissionCount, 1);
    expect(
        SiteDirectorySummary.fromRecords([a, b])
            .firstWhere((row) => row.site.id == 'S1')
            .reports,
        1);
    final actions = ExpertActions.build(
        records: [a.toAdminTableRow(1), b.toAdminTableRow(2)],
        now: DateTime(2026));
    expect(actions.length, 1);
    expect(actions.single.id, expected.displayId);
    final marker = recordDotMarker(b);
    expect(marker.point.latitude, b.latitude);
    expect(marker.point.longitude, b.longitude);
  });

  test('staff grouping splits sites and owners and preserves legacy rows', () {
    final photos = [
      fixtures.photo('a'),
      fixtures.photo('b', site: 'S2'),
      fixtures.photo('c', owner: 'other'),
      fixtures.photo('d', batch: '')
    ];
    final rows = StaffSubmissionRows.group(
        [for (var i = 0; i < photos.length; i++) photos[i].toAdminTableRow(i)]);
    expect(rows.length, 4);
    expect(rows.last.isSubmissionSummary, isFalse);
    expect(rows.last.documentId, 'd');
  });

  test('missing photo IDs remain separate rather than being guessed or dropped',
      () {
    const row =
        AdminRecordTableRow(1, '', 'Site', '', 1, null, 'Low', 'Diver', 90);
    expect(StaffSubmissionRows.group([row, row]).length, 2);
  });

  test('all required reviews must finish before the group is accepted', () {
    final a = fixtures.photo('a', confidence: .6);
    final b = fixtures.photo('b', confidence: .7, accepted: true);
    expect(
        StaffSubmissionRows.group([a.toAdminTableRow(1), b.toAdminTableRow(2)])
            .single
            .displayStatusLabel,
        'Under Review');
    final accepted = fixtures.photo('a', confidence: .6, accepted: true);
    expect(
        StaffSubmissionRows.group(
                [accepted.toAdminTableRow(1), b.toAdminTableRow(2)])
            .single
            .displayStatusLabel,
        'Accepted');
    final processing = fixtures.photo('c', serverStatus: 'pending');
    expect(
        StaffSubmissionRows.group([processing.toAdminTableRow(1)])
            .single
            .displayStatusLabel,
        'Processing evidence');
  });

  test(
      'exports one grouped row with original photo IDs and no invented confidence',
      () {
    final a = fixtures.photo('a', count: 2), b = fixtures.photo('b');
    final csv = utf8.decode(const AdminReportExportService()
        .buildCsv([a.toAdminTableRow(1), b.toAdminTableRow(2)]));
    expect(csv.split('\n').where((line) => line.trim().isNotEmpty).length, 2);
    expect(csv, contains('Per photo'));
    expect(csv, contains(a.displayRecordId));
    expect(csv, contains(b.displayRecordId));
    expect(csv, contains('"3","0","0"'));
  });
}
