import 'package:flutter/material.dart';

import '../../../models/app_notification.dart';
import '../../auth/auth_navigation.dart';
import '../../admin/screens/admin_records_submissions_screen.dart';
import '../../admin/theme/admin_theme.dart';
import '../models/expert_action_item.dart';
import 'expert_assessments_screen.dart';
import 'expert_notifications_screen.dart';
import 'expert_reassignments_screen.dart';
import 'expert_users_screen.dart';

/// Expert-only shell — records verification (approve / reject submissions).
/// The Notifications tab comes first, so the Expert sees what needs action
/// on sign-in (claude/agreed_workflow_decisions.md).
class ExpertShellScreen extends StatefulWidget {
  const ExpertShellScreen({super.key, this.actions, this.noticesStream});

  /// Replaces the "Needs your action" data (tests).
  final ExpertActionsController? actions;

  /// Replaces the Expert's notices (tests).
  final Stream<List<AppNotification>>? noticesStream;

  static const tabLabels = [
    'Notifications',
    'Verification',
    'Reassignments',
    'Assessments',
    'Users',
  ];

  /// The tab where the Expert acts on a "Needs your action" item.
  static int tabFor(ExpertActionPlace place) =>
      tabLabels.indexOf(place.label);

  @override
  State<ExpertShellScreen> createState() => _ExpertShellScreenState();
}

class _ExpertShellScreenState extends State<ExpertShellScreen> {
  late final ExpertActionsController _actions =
      widget.actions ?? ExpertActionsController();

  @override
  void initState() {
    super.initState();
    _actions.start();
  }

  @override
  void dispose() {
    if (widget.actions == null) _actions.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    await confirmAndSignOut(context);
  }

  @override
  Widget build(BuildContext context) {
    return adminThemedSubtree(
      context,
      child: DefaultTabController(
          length: ExpertShellScreen.tabLabels.length,
          child: Builder(
            builder: (context) => Scaffold(
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
                bottom: TabBar(
                    // Five tabs: scroll on narrow phones instead of squeezing.
                    isScrollable: true,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: [
                      Tab(child: ExpertNotificationsTabLabel(actions: _actions)),
                      for (final label
                          in ExpertShellScreen.tabLabels.skip(1))
                        Tab(text: label),
                    ]),
              ),
              body: TabBarView(children: [
                ExpertNotificationsScreen(
                  actions: _actions,
                  noticesStream: widget.noticesStream,
                  onOpen: (place) => DefaultTabController.of(context)
                      .animateTo(ExpertShellScreen.tabFor(place)),
                ),
                const AdminRecordsSubmissionsScreen(
                  viewOnly: false,
                  expertContext: true,
                ),
                const ExpertReassignmentsScreen(),
                const ExpertAssessmentsScreen(),
                const ExpertUsersScreen(),
              ]),
            ),
          )),
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
            Text(ExpertShellScreen.tabLabels.first),
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
