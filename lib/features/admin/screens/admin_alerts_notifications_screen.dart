import 'package:flutter/material.dart';

import 'admin_alerts_screen.dart';
import 'admin_notifications_screen.dart';

/// Groups existing oversight views without changing their data or actions.
class AdminAlertsNotificationsScreen extends StatelessWidget {
  const AdminAlertsNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => const DefaultTabController(
        length: 2,
        child: Column(children: [
          TabBar(tabs: [Tab(text: 'Alerts'), Tab(text: 'Notifications')]),
          Expanded(
            child: TabBarView(children: [
              AdminAlertsScreen(),
              AdminNotificationsScreen(),
            ]),
          ),
        ]),
      );
}
