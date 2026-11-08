import 'package:flutter/material.dart';

import '../../admin/layout/admin_breakpoints.dart';
import '../../admin/theme/admin_theme.dart';
import '../../admin/widgets/admin_stat_card.dart';
import '../models/expert_action_item.dart';
import 'expert_notifications_screen.dart';

/// Summarizes the shell's existing action feed; no additional data source.
class ExpertDashboardScreen extends StatelessWidget {
  const ExpertDashboardScreen({
    super.key,
    required this.actions,
    required this.onOpen,
    required this.onOpenMap,
  });

  final ExpertActionsController actions;
  final ValueChanged<ExpertActionPlace> onOpen;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: actions,
        builder: (context, _) => SingleChildScrollView(
          padding:
              AdminBreakpoints.pagePadding(MediaQuery.sizeOf(context).width),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Expert Dashboard',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.headerTitle)),
              const SizedBox(height: 8),
              const Text('Review field evidence, assignments, and assessments.',
                  style: TextStyle(color: AdminColors.muted)),
              const SizedBox(height: 24),
              if (!actions.loaded) const LinearProgressIndicator(),
              for (final error in actions.errors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(error,
                      style: const TextStyle(color: AdminColors.statRed)),
                ),
              LayoutBuilder(builder: (context, constraints) {
                final width = constraints.maxWidth < 700
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 24) / 3;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final place in ExpertActionPlace.values)
                    SizedBox(
                      width: width,
                      child: AdminStatCard(
                        title: place == ExpertActionPlace.reassignments
                            ? 'Assignments & Reassignments'
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
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onOpenMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open Map Monitoring'),
              ),
              if (actions.errors.isNotEmpty)
                TextButton.icon(
                  onPressed: actions.refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry action summary'),
                ),
            ],
          ),
        ),
      );
}
