import 'package:cots_monitor/features/user/notifications_screen.dart';
import 'package:cots_monitor/models/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('High site levels and rejected records appear in Alerts', () {
    for (final type in [
      'site_level_high',
      AppNotification.reviewRejected,
      AppNotification.recordRejected,
    ]) {
      expect(NotificationCategory.forType(type), NotificationCategory.alerts,
          reason: type);
    }
  });

  test('both monthly reminders and assigned tasks appear in Reminders', () {
    for (final type in [
      'visit_reminder_first',
      'visit_reminder_second',
      AppNotification.interventionAssigned,
      AppNotification.zoneReviewReminder,
    ]) {
      expect(NotificationCategory.forType(type), NotificationCategory.reminders,
          reason: type);
    }
  });

  test('confirmations, approvals and other notices remain Updates', () {
    for (final type in [
      AppNotification.scanSubmitted,
      AppNotification.reviewAccepted,
      AppNotification.recordFinalized,
      AppNotification.zoneRecordApproved,
      AppNotification.followUpReassignment,
      'partner_approved',
      'handover_accepted',
      'system_update',
    ]) {
      expect(NotificationCategory.forType(type), NotificationCategory.updates,
          reason: type);
    }
  });
}
