import 'dart:async';

import 'package:cots_monitor/features/user/widgets/diver_notification_bell.dart';
import 'package:cots_monitor/models/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppNotification _notice(bool read) => AppNotification(
    id: 'notice',
    recipientUid: 'diver',
    type: AppNotification.reviewAccepted,
    title: 'Reviewed',
    body: '',
    relatedRecordId: 'record',
    zone: '',
    dueAt: null,
    createdAt: DateTime(2026),
    isRead: read);

void main() {
  testWidgets(
      'bell follows unread state, keeps navigation, and resets for another user',
      (tester) async {
    final stream = StreamController<List<AppNotification>>.broadcast();
    addTearDown(stream.close);
    var opened = 0;
    Widget page(String uid) => MaterialApp(
        home: Scaffold(
            body: DiverNotificationBell(
                uid: uid,
                notificationsStream: stream.stream,
                onPressed: () => opened++)));
    await tester.pumpWidget(page('diver'));
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    stream.add([_notice(false)]);
    await tester.pump();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
    await tester.tap(find.byType(IconButton));
    expect(opened, 1);
    stream.add([_notice(true)]);
    await tester.pump();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    stream.addError(StateError('offline'));
    await tester.pump();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(page('another-diver'));
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
