import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/admin_record_review_tracker.dart';
import '../../../services/scan_record_repository.dart';
import '../../auth/auth_navigation.dart';
import '../layout/admin_nav_entries.dart';
import '../layout/admin_responsive_chrome.dart';
import '../models/admin_record_table_row.dart';
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
    await confirmAndSignOut(context);
  }

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, kAdminShellPageTitles.length - 1);
  }

  static const int _recordsNavIndex = 3;

  int? _recordsNavBadge(
      AdminRecordReviewTracker tracker, List<AdminRecordTableRow> rows) {
    final count = tracker.unopenedNeedsReviewCount(rows);
    return count > 0 ? count : null;
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<AdminRecordReviewTracker>();

    return StreamBuilder<List<AdminRecordTableRow>>(
      stream: ScanRecordRepository.watchAdminTableRows(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <AdminRecordTableRow>[];
        int? navBadgeFor(int index) {
          if (index == _recordsNavIndex) return _recordsNavBadge(tracker, rows);
          return null;
        }

        return adminThemedSubtree(
          context,
          child: AdminResponsiveChrome(
            selectedNavIndex: _index,
            onNavSelect: (i) => setState(
                () => _index = i.clamp(0, kAdminShellPageTitles.length - 1)),
            onLogout: _logout,
            pageTitle: kAdminShellPageTitles[_index],
            navBadgeFor: navBadgeFor,
            body: switch (_index) {
              0 => AdminDashboardScreen(
                  onOpenMapMonitoring: () => setState(() => _index = 1),
                ),
              1 => const AdminMapMonitoringScreen(),
              2 => const AdminZonesScreen(),
              3 => const AdminRecordsSubmissionsScreen(viewOnly: true),
              4 => const AdminAlertsScreen(),
              5 => const AdminNotificationsScreen(),
              6 => const AdminAnalyticsScreen(),
              7 => const AdminReportsScreen(),
              8 => const AdminUsersScreen(),
              9 => const AdminSettingsScreen(),
              _ => AdminPlaceholderScreen(
                  title: kAdminShellPageTitles[
                      _index.clamp(0, kAdminShellPageTitles.length - 1)],
                ),
            },
          ),
        );
      },
    );
  }
}
