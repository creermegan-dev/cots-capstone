import 'package:flutter/material.dart';

import '../layout/admin_breakpoints.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dashboard_header.dart';

class _NotificationEntry {
  const _NotificationEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.icon,
    required this.iconColor,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final String timeLabel;
  final IconData icon;
  final Color iconColor;
  final bool read;
}

/// In-app notifications list (mock data).
class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  late List<_NotificationEntry> _items;

  static final List<_NotificationEntry> _seed = [
    const _NotificationEntry(
      id: 'n1',
      title: 'New high-density record',
      body: 'Zone A exceeded the COTS density threshold. Review the latest submission.',
      timeLabel: '12 min ago',
      icon: Icons.warning_amber_rounded,
      iconColor: AdminColors.statRed,
    ),
    const _NotificationEntry(
      id: 'n2',
      title: 'Report auto-approved',
      body: 'RPT-00024 was auto-approved based on confidence rules.',
      timeLabel: '1 hr ago',
      icon: Icons.check_circle_outline_rounded,
      iconColor: AdminColors.statGreen,
    ),
    const _NotificationEntry(
      id: 'n3',
      title: 'Scheduled monitoring',
      body: 'Zone C scan is scheduled for tomorrow 08:00 AM.',
      timeLabel: '3 hr ago',
      icon: Icons.schedule_rounded,
      iconColor: AdminColors.statYellow,
    ),
    const _NotificationEntry(
      id: 'n4',
      title: 'System maintenance',
      body: 'Analytics export will be unavailable May 20, 02:00–03:00 AM.',
      timeLabel: 'Yesterday',
      icon: Icons.build_outlined,
      iconColor: AdminColors.statBlue,
      read: true,
    ),
    const _NotificationEntry(
      id: 'n5',
      title: 'New user invitation',
      body: 'An invitation was sent to field.officer@example.gov.ph.',
      timeLabel: 'Yesterday',
      icon: Icons.person_add_alt_1_outlined,
      iconColor: AdminColors.statPurple,
      read: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _items = List<_NotificationEntry>.from(_seed);
  }

  void _onRefresh() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Notifications refreshed (demo).'),
      ),
    );
  }

  void _markRead(int i) {
    if (i < 0 || i >= _items.length || _items[i].read) return;
    setState(() {
      _items[i] = _NotificationEntry(
        id: _items[i].id,
        title: _items[i].title,
        body: _items[i].body,
        timeLabel: _items[i].timeLabel,
        icon: _items[i].icon,
        iconColor: _items[i].iconColor,
        read: true,
      );
    });
  }

  void _markAllRead() {
    setState(() {
      _items = [
        for (final e in _items)
          _NotificationEntry(
            id: e.id,
            title: e.title,
            body: e.body,
            timeLabel: e.timeLabel,
            icon: e.icon,
            iconColor: e.iconColor,
            read: true,
          ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((e) => !e.read).length;
    final pagePad = AdminBreakpoints.pagePadding(MediaQuery.sizeOf(context).width);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pagePad.left, 22, pagePad.right, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminDashboardHeader(
            title: 'Notifications',
            subtitle: 'System alerts, approvals, and monitoring updates for your organization.',
            onRefreshTap: _onRefresh,
          ),
          const SizedBox(height: 18),
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
              if (unread > 0)
                TextButton(
                  onPressed: _markAllRead,
                  child: const Text('Mark all read', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _NotificationTile(
              entry: _items[i],
              onTap: () => _markRead(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.entry, required this.onTap});

  final _NotificationEntry entry;
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
            border: Border.all(color: Colors.black.withValues(alpha: entry.read ? 0.06 : 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: entry.iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(entry.icon, color: entry.iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              entry.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: entry.read ? FontWeight.w600 : FontWeight.w800,
                                color: AdminColors.headerTitle.withValues(alpha: entry.read ? 0.82 : 1),
                              ),
                            ),
                          ),
                          if (!entry.read)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 8, top: 5),
                              decoration: const BoxDecoration(
                                color: AdminColors.statBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.body,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AdminColors.muted.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.timeLabel,
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
      ),
    );
  }
}
