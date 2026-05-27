import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cots_monitor/features/auth/admin_login_screen.dart';
import 'package:cots_monitor/providers/auth_provider.dart';
import '../layout/admin_nav_entries.dart';
import '../layout/admin_responsive_chrome.dart';
import '../theme/admin_theme.dart';
import 'admin_alerts_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_map_monitoring_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_placeholder_screen.dart';
import 'admin_records_submissions_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_users_screen.dart';
import 'admin_zones_screen.dart';

/// Desktop/tablet/mobile admin layout — isolated from user `features/user` flows.
class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  late int _index;

  Future<void> _logout() async {
    if (!context.mounted) return;
    final auth = context.read<AuthProvider>();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AdminLoginScreen()),
    );
    await auth.signOut();
  }

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, kAdminShellPageTitles.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return adminThemedSubtree(
      context,
      child: AdminResponsiveChrome(
        selectedNavIndex: _index,
        onNavSelect: (i) => setState(() => _index = i.clamp(0, kAdminShellPageTitles.length - 1)),
        onLogout: _logout,
        pageTitle: kAdminShellPageTitles[_index],
        body: switch (_index) {
          0 => const AdminDashboardScreen(),
          1 => const AdminMapMonitoringScreen(),
          2 => const AdminZonesManagementScreen(),
          3 => const AdminRecordsSubmissionsScreen(),
          4 => const AdminAlertsScreen(),
          5 => const AdminNotificationsScreen(),
          6 => const AdminAnalyticsScreen(),
          7 => const AdminReportsScreen(),
          8 => const AdminUsersScreen(),
          9 => const AdminSettingsScreen(),
          _ => AdminPlaceholderScreen(title: kAdminShellPageTitles[_index.clamp(0, kAdminShellPageTitles.length - 1)]),
        },
      ),
    );
  }
}
