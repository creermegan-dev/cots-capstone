import 'package:flutter/material.dart';

import '../../core/cots_colors.dart';
import '../../widgets/app_back_icon_button.dart';
import '../../widgets/monitoring_analytics_panel.dart';

class UserAnalyticsOverviewPage extends StatelessWidget {
  const UserAnalyticsOverviewPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: kTextNavy,
            leading: AppBackIconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                iconColor: kTextNavy),
            title: const Text('Analytics Overview',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            centerTitle: true),
        body: const SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: MonitoringAnalyticsPanel()),
      );
}
