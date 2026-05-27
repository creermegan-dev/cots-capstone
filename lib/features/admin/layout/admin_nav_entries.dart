import 'package:flutter/material.dart';

import '../models/admin_nav_models.dart';

/// Single source of truth for admin navigation (sidebar + mobile drawer).
final List<AdminNavEntry> kAdminNavEntries = [
  const AdminNavSectionHeader('DATA & INSIGHTS'),
  const AdminNavItemData(icon: Icons.dashboard_outlined, label: 'Dashboard', index: 0),
  const AdminNavItemData(icon: Icons.map_outlined, label: 'Map Monitoring', index: 1),
  const AdminNavItemData(icon: Icons.grid_view_rounded, label: 'Zones', index: 2),
  const AdminNavItemData(
    icon: Icons.folder_open_outlined,
    label: 'Records / Submissions',
    index: 3,
    badge: 8,
  ),
  const AdminNavItemData(icon: Icons.warning_amber_rounded, label: 'Alerts', index: 4, badge: 6),
  const AdminNavItemData(icon: Icons.notifications_outlined, label: 'Notifications', index: 5, badge: 3),
  const AdminNavItemData(icon: Icons.analytics_outlined, label: 'Analytics', index: 6),
  const AdminNavItemData(icon: Icons.description_outlined, label: 'Reports', index: 7),
  const AdminNavSectionHeader('ADMINISTRATION'),
  const AdminNavItemData(icon: Icons.people_outline_rounded, label: 'Users', index: 8),
  const AdminNavItemData(icon: Icons.settings_outlined, label: 'Settings', index: 9),
];

const List<String> kAdminShellPageTitles = [
  'Dashboard',
  'Map Monitoring',
  'Zones',
  'Records / Submissions',
  'Alerts',
  'Notifications',
  'Analytics',
  'Reports',
  'Users',
  'Settings',
];
