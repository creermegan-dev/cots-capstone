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
  const AdminNavItemData(
      icon: Icons.warning_amber_rounded,
      label: 'Alerts & Notifications',
      index: 4),
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
  'Alerts & Notifications',
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
      icon: Icons.swap_horiz_rounded,
      label: 'Assignments & Reassignments',
      index: 3),
  const AdminNavItemData(
      icon: Icons.rate_review_outlined, label: 'Assessments', index: 4),
  const AdminNavItemData(
      icon: Icons.map_outlined, label: 'Map Monitoring', index: 5),
  const AdminNavItemData(
      icon: Icons.notifications_outlined, label: 'Notifications', index: 6),
];
