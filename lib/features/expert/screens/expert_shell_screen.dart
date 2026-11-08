import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/app_notification.dart';
import '../../../providers/auth_provider.dart';
import '../../admin/layout/admin_nav_entries.dart';
import '../../admin/layout/admin_responsive_chrome.dart';
import '../../admin/screens/admin_records_submissions_screen.dart';
import '../../admin/screens/admin_map_monitoring_screen.dart';
import '../../admin/theme/admin_theme.dart';
import '../../auth/auth_navigation.dart';
import '../models/expert_action_item.dart';
import 'expert_assessments_screen.dart';
import 'expert_dashboard_screen.dart';
import 'expert_notifications_screen.dart';
import 'expert_reassignments_screen.dart';
import 'expert_users_screen.dart';

/// Expert-only shell — records verification (approve / reject submissions).
/// Uses the responsive left sidebar layout matching the administrator panel.
class ExpertShellScreen extends StatefulWidget {
  const ExpertShellScreen({
    super.key,
    this.initialIndex = 0,
    this.actions,
    this.noticesStream,
  });

  final int initialIndex;

  /// Replaces the "Needs your action" data (tests).
  final ExpertActionsController? actions;

  /// Replaces the Expert's notices (tests).
  final Stream<List<AppNotification>>? noticesStream;

  static const tabLabels = [
    'Dashboard',
    'Verification',
    'Personnel Verification',
    'Assignments & Reassignments',
    'Assessments',
    'Map Monitoring',
    'Notifications',
  ];

  /// The tab where the Expert acts on a "Needs your action" item.
  static int tabFor(ExpertActionPlace place) => switch (place) {
        ExpertActionPlace.verification => 1,
        ExpertActionPlace.reassignments => 3,
        ExpertActionPlace.assessments => 4,
      };

  @override
  State<ExpertShellScreen> createState() => _ExpertShellScreenState();
}

class _ExpertShellScreenState extends State<ExpertShellScreen> {
  late int _index;
  late final ExpertActionsController _actions =
      widget.actions ?? ExpertActionsController();

  @override
  void initState() {
    super.initState();
    _index =
        widget.initialIndex.clamp(0, ExpertShellScreen.tabLabels.length - 1);
    _actions.start();
  }

  @override
  void dispose() {
    if (widget.actions == null) _actions.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await confirmAndSignOut(context);
  }

  String _resolveExpertName() {
    try {
      final auth = Provider.of<AuthProvider?>(context, listen: false);
      final name = auth?.userModel?.fullName.trim();
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    return 'Expert User';
  }

  @override
  Widget build(BuildContext context) {
    return adminThemedSubtree(
      context,
      child: DefaultTabController(
        length: ExpertShellScreen.tabLabels.length,
        initialIndex: _index,
        child: ListenableBuilder(
          listenable: _actions,
          builder: (context, _) {
            int? navBadgeFor(int index) {
              if (index == 6 && _actions.count > 0) {
                return _actions.count;
              }
              return null;
            }

            return AdminResponsiveChrome(
              selectedNavIndex: _index,
              onNavSelect: (i) => setState(() =>
                  _index = i.clamp(0, ExpertShellScreen.tabLabels.length - 1)),
              onLogout: _logout,
              pageTitle: ExpertShellScreen.tabLabels[_index],
              navBadgeFor: navBadgeFor,
              navEntries: kExpertNavEntries,
              panelSubtitle: 'Expert Workspace',
              userName: _resolveExpertName(),
              userRole: 'Marine Expert',
              body: switch (_index) {
                0 => ExpertDashboardScreen(
                    actions: _actions,
                    onOpen: (place) => setState(
                        () => _index = ExpertShellScreen.tabFor(place)),
                    onOpenMap: () => setState(() => _index = 5),
                  ),
                6 => ExpertNotificationsScreen(
                    actions: _actions,
                    noticesStream: widget.noticesStream,
                    onOpen: (place) => setState(
                        () => _index = ExpertShellScreen.tabFor(place)),
                  ),
                1 => const AdminRecordsSubmissionsScreen(
                    viewOnly: false,
                    expertContext: true,
                  ),
                2 => const ExpertUsersScreen(),
                3 => const ExpertReassignmentsScreen(),
                4 => const ExpertAssessmentsScreen(),
                5 => const AdminMapMonitoringScreen(),
                _ => ExpertNotificationsScreen(
                    actions: _actions,
                    noticesStream: widget.noticesStream,
                    onOpen: (place) => setState(
                        () => _index = ExpertShellScreen.tabFor(place)),
                  ),
              },
            );
          },
        ),
      ),
    );
  }
}

/// "Notifications" with the number of items that need the Expert's action.
class ExpertNotificationsTabLabel extends StatelessWidget {
  const ExpertNotificationsTabLabel({super.key, required this.actions});

  final ExpertActionsController actions;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: actions,
        builder: (context, _) {
          final count = actions.count;
          return Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('Notifications'),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                key: const ValueKey('expert-action-count'),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AdminColors.statRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ]);
        },
      );
}
