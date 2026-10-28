import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/app_notification.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/notification_repository.dart';
import '../../../widgets/cots_loading_skeleton.dart';
import '../layout/admin_breakpoints.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dashboard_header.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({
    super.key,
    this.notificationsStream,
    this.recipientUid,
  });

  final Stream<List<AppNotification>>? notificationsStream;
  final String? recipientUid;

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  Stream<List<AppNotification>>? _notificationsStream;
  String? _activeUid;

  @override
  void initState() {
    super.initState();
    _notificationsStream = widget.notificationsStream;
    _activeUid = widget.recipientUid;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.notificationsStream != null) return;
    final auth = context.read<AuthProvider>();
    final uid =
        widget.recipientUid ?? auth.userModel?.uid ?? auth.firebaseUser?.uid;
    if (uid == null || uid.isEmpty || uid == _activeUid) return;
    _activeUid = uid;
    _notificationsStream = NotificationRepository.watchForUser(uid);
  }

  void _onRefresh() {
    final uid = _activeUid;
    if (widget.notificationsStream == null && uid != null && uid.isNotEmpty) {
      setState(() {
        _notificationsStream = NotificationRepository.watchForUser(uid);
      });
    }
    _showMessage('Notifications refreshed from Firebase.');
  }

  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await NotificationRepository.markRead(notification.id);
    } catch (error) {
      _showMessage('Could not mark notification as read: $error');
    }
  }

  Future<void> _markAllRead(List<AppNotification> notifications) async {
    try {
      await NotificationRepository.markAllRead(notifications);
    } catch (error) {
      _showMessage('Could not mark notifications as read: $error');
    }
  }

  Future<void> _clearAll(List<AppNotification> notifications) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear notifications?'),
        content: const Text(
            'This permanently removes all notifications from this account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await NotificationRepository.clearAll(notifications);
    } catch (error) {
      _showMessage('Could not clear notifications: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pagePad =
        AdminBreakpoints.pagePadding(MediaQuery.sizeOf(context).width);
    final stream = _notificationsStream;

    return StreamBuilder<List<AppNotification>>(
      stream: stream,
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? const <AppNotification>[];
        final unread = notifications.where((item) => !item.isRead).length;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pagePad.left, 22, pagePad.right, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminDashboardHeader(
                title: 'Notifications',
                subtitle:
                    'Real system activities, assignments, and review updates.',
                onRefreshTap: _onRefresh,
              ),
              const SizedBox(height: 18),
              if (stream == null)
                _messageCard(
                  icon: Icons.lock_outline_rounded,
                  title: 'Sign in required',
                  message: 'Sign in again to load your notifications.',
                )
              else if (snapshot.hasError)
                _messageCard(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load notifications',
                  message: '${snapshot.error}',
                  action: TextButton.icon(
                    onPressed: _onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                )
              else if (!snapshot.hasData)
                const CotsLoadingSkeleton(
                  layout: CotsSkeletonLayout.list,
                  label: 'Loading administrator notifications',
                )
              else ...[
                Row(
                  children: [
                    Text(
                      unread > 0 ? '$unread unread' : 'All caught up',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.muted.withValues(alpha: 0.9),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: notifications.isEmpty
                          ? null
                          : () => _clearAll(notifications),
                      child: const Text('Clear all'),
                    ),
                    if (unread > 0)
                      TextButton(
                        onPressed: () => _markAllRead(notifications),
                        child: const Text('Mark all read'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (notifications.isEmpty)
                  _messageCard(
                    icon: Icons.notifications_none_rounded,
                    title: 'No notifications yet',
                    message:
                        'New activities assigned to this administrator will appear here.',
                  )
                else
                  for (var i = 0; i < notifications.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _NotificationTile(
                      notification: notifications[i],
                      onTap: () => _markRead(notifications[i]),
                    ),
                  ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _messageCard({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 38, color: AdminColors.muted),
          const SizedBox(height: 10),
          Text(title,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AdminColors.muted)),
          if (action != null) ...[const SizedBox(height: 10), action],
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (notification.type) {
      AppNotification.reviewAccepted => (
          Icons.check_circle_outline_rounded,
          AdminColors.statGreen
        ),
      AppNotification.reviewRejected => (
          Icons.warning_amber_rounded,
          AdminColors.statRed
        ),
      AppNotification.interventionAssigned => (
          Icons.assignment_ind_outlined,
          AdminColors.statYellow
        ),
      'follow_up_reassignment' => (
          Icons.swap_horiz_rounded,
          AdminColors.statPurple
        ),
      _ => (Icons.description_outlined, AdminColors.statBlue),
    };
    final createdAt = notification.createdAt;
    final timeLabel = createdAt == null
        ? 'Just now'
        : DateFormat('MMM d, yyyy · h:mm a').format(createdAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.black
                  .withValues(alpha: notification.isRead ? 0.06 : 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              color: AdminColors.headerTitle,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AdminColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.muted.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
