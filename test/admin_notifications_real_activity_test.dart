import 'package:cots_monitor/features/admin/screens/admin_notifications_screen.dart';
import 'package:cots_monitor/models/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin notifications render real activity stream data',
      (tester) async {
    final activity = AppNotification(
      id: 'notification-real-1',
      recipientUid: 'admin-1',
      type: AppNotification.reviewAccepted,
      title: 'Real review completed',
      body: 'CAP-REAL-001 was accepted by an expert.',
      relatedRecordId: 'CAP-REAL-001',
      zone: 'Test Reef',
      dueAt: null,
      createdAt: DateTime(2026, 10, 25, 20, 30),
      isRead: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminNotificationsScreen(
            recipientUid: 'admin-1',
            notificationsStream: Stream.value([activity]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Real review completed'), findsOneWidget);
    expect(
        find.text('CAP-REAL-001 was accepted by an expert.'), findsOneWidget);
    expect(find.text('New high-density record'), findsNothing);
    expect(find.text('1 unread'), findsOneWidget);
  });
}
