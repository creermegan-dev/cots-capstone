import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cots_monitor/providers/auth_provider.dart';
import '../layout/admin_breakpoints.dart';
import '../layout/admin_responsive_chrome.dart';
import '../models/admin_report_modal_data.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_back_icon_button.dart';
import '../widgets/admin_dashboard_header.dart';
import '../widgets/admin_report_modals.dart';
import 'admin_shell_screen.dart';

/// Full-page report details (same content as the former modal).
class AdminReportDetailsScreen extends StatefulWidget {
  const AdminReportDetailsScreen({super.key, required this.data});

  final AdminReportModalData data;

  @override
  State<AdminReportDetailsScreen> createState() => _AdminReportDetailsScreenState();
}

class _AdminReportDetailsScreenState extends State<AdminReportDetailsScreen> {
  Future<void> _logout() async {
    if (!context.mounted) return;
    await context.read<AuthProvider>().signOut();
  }

  void _onSidebarSelect(int index) {
    if (index == 7) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AdminShellScreen(initialIndex: index),
      ),
    );
  }

  void _onHeaderRefresh() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Report details refreshed (demo).'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return adminThemedSubtree(
      context,
      child: AdminResponsiveChrome(
        selectedNavIndex: 7,
        onNavSelect: _onSidebarSelect,
        onLogout: _logout,
        pageTitle: 'Report Details',
        showBackButton: false,
        onBack: null,
        body: LayoutBuilder(
          builder: (context, c) {
            return SingleChildScrollView(
              padding: AdminBreakpoints.pagePadding(c.maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminDashboardHeader(
                    leading: AdminBackIconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    title: 'Report Details',
                    subtitle: 'Detailed information about the submitted report.',
                    onRefreshTap: _onHeaderRefresh,
                  ),
                  const SizedBox(height: 16),
                  AdminReportDetailsContent(data: widget.data),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
