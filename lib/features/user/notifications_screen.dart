import 'package:cots_monitor/widgets/app_back_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/cots_colors.dart';
import '../../models/app_notification.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_repository.dart';
import 'cots_map_page.dart';
import 'profile_page.dart';
import 'records_page.dart';
import 'user_bottom_nav.dart';

enum NotificationCategory { all, alerts, reminders, updates }

/// Row data for [NotificationCard].
class NotificationListItem {
  const NotificationListItem({
    required this.id,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.timeText,
    required this.accent,
    required this.iconBg,
    required this.icon,
    required this.category,
    required this.section,
    required this.unread,
  });

  final String id;
  final String title;
  final String description;
  final String actionLabel;
  final String timeText;
  final Color accent;
  final Color iconBg;
  final IconData icon;
  final NotificationCategory category;
  final String section;
  final bool unread;
}

/// Notifications list + filters matching COTS Monitor mockup.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationCategory _filter = NotificationCategory.all;

  List<NotificationListItem> _visible(List<NotificationListItem> all) {
    if (_filter == NotificationCategory.all) return all;
    return all.where((item) => item.category == _filter).toList();
  }

  Iterable<String> _sections(List<NotificationListItem> visible) sync* {
    final seen = <String>{};
    for (final n in visible) {
      if (seen.add(n.section)) yield n.section;
    }
  }

  NotificationListItem _itemFor(AppNotification notification) {
    final createdAt = notification.createdAt;
    final today = DateUtils.isSameDay(createdAt, DateTime.now());
    final category = switch (notification.type) {
      AppNotification.interventionAssigned => NotificationCategory.reminders,
      AppNotification.reviewRejected => NotificationCategory.alerts,
      _ => NotificationCategory.updates,
    };
    final accent = switch (notification.type) {
      AppNotification.interventionAssigned => kWarningOrange,
      AppNotification.reviewAccepted => kSuccessGreen,
      AppNotification.reviewRejected => kDangerRed,
      _ => kAccentPurple,
    };
    final icon = switch (notification.type) {
      AppNotification.interventionAssigned => Icons.event_note_rounded,
      AppNotification.reviewAccepted => Icons.check_circle_outline_rounded,
      AppNotification.reviewRejected => Icons.warning_amber_rounded,
      _ => Icons.event_available_rounded,
    };
    return NotificationListItem(
      id: notification.id,
      title: notification.title,
      description: notification.body,
      actionLabel: notification.type == AppNotification.interventionAssigned
          ? 'View task'
          : 'View record',
      timeText: createdAt == null ? 'Just now' : DateFormat('h:mm a').format(createdAt),
      accent: accent,
      iconBg: accent.withValues(alpha: 0.13),
      icon: icon,
      category: category,
      section: today ? 'Today' : 'Earlier',
      unread: !notification.isRead,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().userModel?.uid;
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: AppBackIconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          iconColor: kTextNavy,
        ),
        centerTitle: true,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: kTextNavy,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: kTextNavy, size: 24),
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButton: userShellScanFab(
        context,
        backgroundColor: kSuccessGreen,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: UserBottomNavBar(
        active: null,
        mapPageBuilder: () => const CotsMapPage(),
        recordsPageBuilder: () => const RecordsPage(),
        profilePageBuilder: () => const ProfilePage(),
      ),
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<AppNotification>>(
          stream: uid == null ? null : NotificationRepository.watchForUser(uid),
          builder: (context, snapshot) {
            final notifications = snapshot.data ?? const <AppNotification>[];
            final visible = _visible(notifications.map(_itemFor).toList());
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            const SizedBox(height: 4),
            _FilterTabs(
              selected: _filter,
              onChanged: (v) => setState(() => _filter = v),
            ),
            Expanded(
              child: snapshot.hasError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not load notifications.\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: kMutedGray),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      children: [
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const Padding(
                            padding: EdgeInsets.only(top: 32),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (visible.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 32),
                            child: Center(
                              child: Text(
                                'No notifications yet.',
                                style: TextStyle(color: kMutedGray),
                              ),
                            ),
                          ),
                        for (final section in _sections(visible)) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                      child: Text(
                        section,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kTextNavy,
                        ),
                      ),
                    ),
                    ...visible.where((n) => n.section == section).map(
                          (item) {
                            final notification = notifications.firstWhere(
                              (value) => value.id == item.id,
                            );
                            return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: NotificationCard(
                              model: item,
                              onTap: () {
                                if (!notification.isRead) {
                                  NotificationRepository.markRead(notification.id);
                                }
                              },
                            ),
                          );
                          },
                        ),
                  ],
                  const SizedBox(height: 12),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: notifications.isEmpty
                        ? null
                        : () => NotificationRepository.clearAll(notifications),
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: kDangerRed, size: 20),
                    label: const Text(
                      'Clear All',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: kDangerRed,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: notifications.every((item) => item.isRead)
                        ? null
                        : () => NotificationRepository.markAllRead(notifications),
                    icon: const Icon(Icons.done_all_rounded,
                        color: kSuccessGreen, size: 20),
                    label: const Text(
                      'Mark all as read',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: kSuccessGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 72),
              ],
            );
          },
        ),
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.model,
    required this.onTap,
  });

  final NotificationListItem model;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorderGray),
            boxShadow: kSoftCardShadow,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: model.accent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(13),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 6, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: model.iconBg,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(model.icon, color: model.accent, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                model.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: kTextNavy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                model.description,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: kMutedGray,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 16,
                                    color: model.accent,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      model.actionLabel,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: model.accent,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 96),
                                  child: Text(
                                    model.timeText.split('\n').first,
                                    textAlign: TextAlign.end,
                                    maxLines: 2,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: kMutedGray,
                                    ),
                                  ),
                                ),
                                if (model.unread) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: model.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (model.timeText.contains('\n'))
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  model.timeText.split('\n').skip(1).first,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: kMutedGray,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: kMutedGray,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.selected,
    required this.onChanged,
  });

  final NotificationCategory selected;
  final ValueChanged<NotificationCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            icon: null,
            accent: kSuccessGreen,
            selected: selected == NotificationCategory.all,
            onTap: () => onChanged(NotificationCategory.all),
          ),
          const SizedBox(width: 10),
          _FilterChip(
            label: 'Alerts',
            icon: Icons.notifications_active_outlined,
            iconColor: kDangerRed,
            accent: kDangerRed,
            selected: selected == NotificationCategory.alerts,
            onTap: () => onChanged(NotificationCategory.alerts),
          ),
          const SizedBox(width: 10),
          _FilterChip(
            label: 'Reminders',
            icon: Icons.schedule_rounded,
            iconColor: kWarningOrange,
            accent: kWarningOrange,
            selected: selected == NotificationCategory.reminders,
            onTap: () => onChanged(NotificationCategory.reminders),
          ),
          const SizedBox(width: 10),
          _FilterChip(
            label: 'Updates',
            icon: Icons.check_circle_outline_rounded,
            iconColor: kSuccessGreen,
            accent: kSuccessGreen,
            selected: selected == NotificationCategory.updates,
            onTap: () => onChanged(NotificationCategory.updates),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.accent,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconColor,
  });

  final String label;
  final IconData? icon;
  final Color? iconColor;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderGray),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: iconColor ?? accent),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? accent : kTextNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 3,
              width: 36,
              decoration: BoxDecoration(
                color: selected ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
