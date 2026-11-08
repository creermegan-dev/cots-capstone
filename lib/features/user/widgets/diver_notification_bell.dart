import 'package:flutter/material.dart';

import '../../../core/cots_colors.dart';
import '../../../models/app_notification.dart';
import '../../../services/notification_repository.dart';

class DiverNotificationBell extends StatefulWidget {
  const DiverNotificationBell(
      {super.key,
      required this.uid,
      required this.onPressed,
      this.notificationsStream});

  final String? uid;
  final VoidCallback onPressed;
  final Stream<List<AppNotification>>? notificationsStream;

  @override
  State<DiverNotificationBell> createState() => _DiverNotificationBellState();
}

class _DiverNotificationBellState extends State<DiverNotificationBell> {
  late Stream<List<AppNotification>> _stream;
  bool _unread = false;

  void _reset() {
    _unread = false;
    _stream = widget.notificationsStream ??
        (widget.uid == null
            ? Stream.value(const <AppNotification>[])
            : NotificationRepository.watchForUser(widget.uid!));
  }

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant DiverNotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid ||
        oldWidget.notificationsStream != widget.notificationsStream) {
      _reset();
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<AppNotification>>(
        key: ValueKey(widget.uid),
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasData && !snapshot.hasError) {
            _unread =
                snapshot.data!.any((notification) => !notification.isRead);
          }
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorderGray),
                boxShadow: kSoftCardShadow),
            child: IconButton(
              tooltip:
                  _unread ? 'Notifications: unread messages' : 'Notifications',
              padding: EdgeInsets.zero,
              onPressed: widget.onPressed,
              icon: Badge(
                isLabelVisible: _unread,
                backgroundColor: Colors.red,
                child: const Icon(Icons.notifications_outlined,
                    color: kTextNavy, size: 20),
              ),
            ),
          );
        },
      );
}
