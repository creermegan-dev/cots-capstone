import 'package:flutter/material.dart';

import '../../../widgets/monitoring_analytics_panel.dart';
import '../layout/admin_breakpoints.dart';
import '../theme/admin_theme.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final padding = AdminBreakpoints.pagePadding(constraints.maxWidth);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(padding.left, 22, padding.right, 28),
          child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Analytics',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.headerTitle)),
                SizedBox(height: 6),
                Text(
                    'Live monitoring records, AI detections, and Expert decisions.',
                    style: TextStyle(color: AdminColors.muted)),
                SizedBox(height: 18),
                MonitoringAnalyticsPanel(),
              ]),
        );
      });
}
