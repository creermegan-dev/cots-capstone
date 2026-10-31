import 'dart:io';

import 'package:cots_monitor/features/admin/models/admin_record_table_row.dart';
import 'package:cots_monitor/models/app_notification.dart';
import 'package:cots_monitor/models/capture_model.dart';
import 'package:cots_monitor/models/cots_detection_result.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/models/zone_review.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stage 2 (claude/agreed_workflow_decisions.md): another Diver's record in
/// an assigned zone waits for the Expert's approval.
const _sure = [
  CotsBoundingBox(x1: 10, y1: 10, x2: 60, y2: 60, score: 0.95),
  CotsBoundingBox(x1: 100, y1: 10, x2: 160, y2: 60, score: 0.9),
];

CaptureModel _capture({String zoneAssignedTo = '', bool confirmed = false}) =>
    CaptureModel(
      id: 'cap-1',
      uid: 'diver-b',
      submittedBy: 'Diver Bravo',
      imageName: 'reef.jpg',
      aiDetectedCount: 2,
      confidence: 0.925,
      captureSource: 'GoPro Underwater Image',
      zone: 'Stage Two Reef',
      notes: '',
      submittedAt: DateTime(2026, 10, 31, 9),
      detectionBoxes: _sure,
      imageWidth: 640,
      imageHeight: 480,
      adminConfirmed: confirmed,
      zoneAssignedTo: zoneAssignedTo,
    );

AdminRecordTableRow _row({String zoneAssignedTo = '', bool confirmed = false}) =>
    AdminRecordTableRow(1, 'CAP-1', 'Stage Two Reef', 'Oct 31, 2026', 2, null,
        'Low', 'Diver Bravo', 93,
        detectionBoxes: _sure,
        imageWidth: 640,
        imageHeight: 480,
        adminConfirmed: confirmed,
        zoneAssignedTo: zoneAssignedTo);

void main() {
  test('the other Diver sees the agreed message', () {
    expect(ZoneReview.waitingMessage('Diver Alpha'),
        'This zone is currently assigned to Diver Alpha. Your record was sent to the Expert for review.');
  });

  test('the waiting record uses the agreed status', () {
    expect(ZoneReview.statusLabel, 'Unassigned Diver - waiting for Expert');
  });

  test('the Expert checks the four agreed points', () {
    expect(ZoneReview.expertChecks,
        ['Right place', 'Not a duplicate', 'Real COTS', 'Sensible count']);
  });

  test('rejecting a zone record needs a reason; approving and others do not',
      () {
    expect(
        ZoneReview.rejectReasonError(assignedTo: 'Diver Alpha', reason: '  '),
        ZoneReview.rejectReasonRequired);
    expect(
        ZoneReview.rejectReasonError(
            assignedTo: 'Diver Alpha', reason: 'Duplicate of CAP-2'),
        isNull);
    expect(ZoneReview.rejectReasonError(assignedTo: '', reason: ''), isNull);
  });

  test('a waiting zone record is Under Review even when the AI is sure', () {
    expect(_row().displayStatusLabel, 'Accepted');
    expect(_row(zoneAssignedTo: 'Diver Alpha').displayStatusLabel,
        'Under Review');
    expect(
        _row(zoneAssignedTo: 'Diver Alpha', confirmed: true).displayStatusLabel,
        'Accepted');
    expect(
        _row(zoneAssignedTo: 'Diver Alpha')
            .copyWith(adminConfirmed: true)
            .zoneAssignedTo,
        'Diver Alpha');
  });

  test('Diver B\'s record shows that it waits for Expert approval', () {
    final record =
        ScanRecordModel.fromCapture(_capture(zoneAssignedTo: 'Diver Alpha'));
    expect(record.userStatusLabel, ZoneReview.statusLabel);
    expect(record.userStatusDescription,
        ZoneReview.waitingMessage('Diver Alpha'));
    expect(record.toAdminTableRow(1).zoneAssignedTo, 'Diver Alpha');
    final approved = ScanRecordModel.fromCapture(
        _capture(zoneAssignedTo: 'Diver Alpha', confirmed: true));
    expect(approved.userStatusLabel, isNot(ZoneReview.statusLabel));
    final normal = ScanRecordModel.fromCapture(_capture());
    expect(normal.userStatusLabel, isNot(ZoneReview.statusLabel));
  });

  test('notification types match the database actions', () {
    final sql = File(
      'supabase/migrations/20261031000200_zone_responsibility.sql',
    ).readAsStringSync();
    for (final action in [
      AppNotification.zoneReviewNeeded,
      AppNotification.zoneReviewReminder,
      AppNotification.zoneReviewWaiting,
      AppNotification.zoneRecordApproved,
    ]) {
      expect(sql, contains("'$action'"));
    }
    expect(sql, contains("'This zone is currently assigned to '"));
    expect(sql, contains('. The Expert approved the record.'));
    expect(sql, contains("interval '3 days'"));
    expect(sql, contains('cots-zone-review-reminders'));
  });
}
