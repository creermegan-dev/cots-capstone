import 'package:flutter/material.dart';

import '../../admin/layout/admin_breakpoints.dart';
import '../../admin/theme/admin_theme.dart';
import '../../admin/widgets/admin_stat_card.dart';
import '../../../core/supabase_config.dart';
import '../../../services/site_levels_service.dart';
import '../../../widgets/site_levels_row.dart';
import '../models/expert_action_item.dart';
import 'expert_notifications_screen.dart';

/// Summarizes the shell's existing action feed; no additional data source.
class ExpertDashboardScreen extends StatelessWidget {
  const ExpertDashboardScreen({
    super.key,
    required this.actions,
    required this.onOpen,
    required this.onOpenMap,
    this.siteLevels,
  });

  final ExpertActionsController actions;
  final ValueChanged<ExpertActionPlace> onOpen;
  final VoidCallback onOpenMap;

  /// Tests replace the site levels source.
  final Future<List<SiteLevel>> Function(DateTime month)? siteLevels;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: actions,
        builder: (context, _) => SingleChildScrollView(
          padding:
              AdminBreakpoints.pagePadding(MediaQuery.sizeOf(context).width),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Expert Dashboard',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: AdminColors.headerTitle)),
                      SizedBox(height: 4),
                      Text(
                          'Review field evidence, site coverage and site levels.',
                          style: TextStyle(
                              fontSize: 13, color: AdminColors.muted)),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenMap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminColors.headerTitle,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.map_outlined,
                        size: 18, color: AdminColors.statBlue),
                    label: const Text(
                      'Open Map Monitoring',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (!actions.loaded) const LinearProgressIndicator(),
              for (final error in actions.errors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(error,
                      style: const TextStyle(color: AdminColors.statRed)),
                ),
              LayoutBuilder(builder: (context, constraints) {
                final width = constraints.maxWidth < 640
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  // Assessments were removed 2026-11-08 (levels are automatic).
                  for (final place in ExpertActionPlace.values
                      .where((p) => p != ExpertActionPlace.assessments))
                    SizedBox(
                      width: width,
                      child: AdminStatCard(
                        title: place == ExpertActionPlace.reassignments
                            ? 'Site Coverage'
                            : place.label,
                        value: !actions.loaded || actions.errors.isNotEmpty
                            ? '—'
                            : '${actions.items.where((item) => item.place == place).length}',
                        subtitle: 'Items needing your action',
                        icon: switch (place) {
                          ExpertActionPlace.verification =>
                            Icons.fact_check_outlined,
                          ExpertActionPlace.reassignments =>
                            Icons.swap_horiz_rounded,
                          ExpertActionPlace.assessments =>
                            Icons.rate_review_outlined,
                        },
                        accentColor: AdminColors.statBlue,
                        onTap: () => onOpen(place),
                      ),
                    ),
                ]);
              }),
              // 2026-11-08: each site's level this month, High first.
              if (SupabaseConfig.isConfigured || siteLevels != null) ...[
                const SizedBox(height: 20),
                SiteLevelsRow(levels: siteLevels),
              ],
              if (actions.errors.isNotEmpty) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: actions.refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry action summary'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}