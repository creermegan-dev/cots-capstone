import 'package:flutter/material.dart';

import '../models/admin_nav_models.dart';

/// Single source of truth for admin navigation (sidebar + mobile drawer).
final List<AdminNavEntry> kAdminNavEntries = [
  const AdminNavSectionHeader('DATA & INSIGHTS'),
  const AdminNavItemData(
      icon: Icons.dashboard_outlined, label: 'Dashboard', index: 0),
  const AdminNavItemData(
      icon: Icons.map_outlined, label: 'Map Monitoring', index: 1),
  const AdminNavItemData(
      icon: Icons.grid_view_rounded, label: 'Sites', index: 2),
  const AdminNavItemData(
    icon: Icons.folder_open_outlined,
    label: 'Records / Submissions',
    index: 3,
  ),
  // 2026-11-08: the record-list Alerts tab was removed; High site levels
  // arrive as notifications and on the Dashboard.
  const AdminNavItemData(
      icon: Icons.notifications_outlined, label: 'Notifications', index: 4),
  const AdminNavItemData(
      icon: Icons.analytics_outlined, label: 'Analytics', index: 5),
  const AdminNavItemData(
      icon: Icons.description_outlined, label: 'Reports', index: 6),
  const AdminNavSectionHeader('ADMINISTRATION'),
  const AdminNavItemData(
      icon: Icons.people_outline_rounded, label: 'Users', index: 7),
  const AdminNavItemData(
      icon: Icons.settings_outlined, label: 'Settings', index: 8),
];

const List<String> kAdminShellPageTitles = [
  'Dashboard',
  'Map Monitoring',
  'Sites',
  'Records / Submissions',
  'Notifications',
  'Analytics',
  'Reports',
  'Users',
  'Settings',
];

/// Single source of truth for expert navigation (sidebar + mobile drawer).
final List<AdminNavEntry> kExpertNavEntries = [
  const AdminNavSectionHeader('EXPERT WORKSPACE'),
  const AdminNavItemData(
      icon: Icons.dashboard_outlined, label: 'Dashboard', index: 0),
  const AdminNavItemData(
      icon: Icons.fact_check_outlined, label: 'Verification', index: 1),
  const AdminNavItemData(
      icon: Icons.people_outline_rounded,
      label: 'Personnel Verification',
      index: 2),
  const AdminNavItemData(
      icon: Icons.swap_horiz_rounded, label: 'Site Coverage', index: 3),
  // Index 4 (Assessments) removed 2026-11-08: site levels are automatic.
  const AdminNavItemData(
      icon: Icons.map_outlined, label: 'Map Monitoring', index: 5),
  const AdminNavItemData(
      icon: Icons.notifications_outlined, label: 'Notifications', index: 6),
];
