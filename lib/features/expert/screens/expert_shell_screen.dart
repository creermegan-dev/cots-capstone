import 'package:flutter/material.dart';

import '../../auth/auth_navigation.dart';
import '../../admin/screens/admin_records_submissions_screen.dart';
import '../../admin/theme/admin_theme.dart';
import 'expert_reassignments_screen.dart';

/// Expert-only shell — records verification (approve / reject submissions).
class ExpertShellScreen extends StatelessWidget {
  const ExpertShellScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await confirmAndSignOut(context);
  }

  @override
  Widget build(BuildContext context) {
    return adminThemedSubtree(
      context,
      child: DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: AdminColors.contentBg,
            appBar: AppBar(
              scrolledUnderElevation: 0,
              elevation: 0,
              backgroundColor: AdminColors.sidebarTop,
              foregroundColor: Colors.white,
              title: const Text(
                'Expert Workspace',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              actions: [
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout_rounded),
                ),
                const SizedBox(width: 8),
              ],
              bottom: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [
                    Tab(text: 'Verification'),
                    Tab(text: 'Reassignments')
                  ]),
            ),
            body: const TabBarView(children: [
              AdminRecordsSubmissionsScreen(
                viewOnly: false,
                expertContext: true,
              ),
              ExpertReassignmentsScreen()
            ]),
          )),
    );
  }
}
