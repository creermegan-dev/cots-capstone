import 'package:flutter/material.dart';

import '../../../core/cots_colors.dart';

/// The two tabs at the top of the Diver's Records page (user, 2026-11-06):
/// "My records" (every submitted encounter) and "Monthly visits" (the
/// monthly follow-up of the Diver's sites).
enum RecordsSection { records, visits }

class RecordsSectionTabs extends StatelessWidget
    implements PreferredSizeWidget {
  const RecordsSectionTabs({
    super.key,
    required this.active,
    required this.onOpen,
  });

  final RecordsSection active;

  /// Opens the other tab (replaces the current page, no animation).
  final void Function(BuildContext context, RecordsSection section) onOpen;

  static const recordsLabel = 'My records';
  static const visitsLabel = 'Monthly visits';

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              for (final section in RecordsSection.values)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        left: section == RecordsSection.visits ? 4 : 0,
                        right: section == RecordsSection.records ? 4 : 0),
                    child: _Tab(
                      label: section == RecordsSection.records
                          ? recordsLabel
                          : visitsLabel,
                      icon: section == RecordsSection.records
                          ? Icons.description_outlined
                          : Icons.event_repeat_outlined,
                      selected: section == active,
                      onTap: section == active
                          ? null
                          : () => onOpen(context, section),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? kTextNavy : const Color(0xFFEFF3F7),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 18,
                      color: selected ? Colors.white : kTextNavy),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : kTextNavy)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Replaces the current page without the slide animation, so the two tabs
/// feel like one page.
Route<void> recordsSectionRoute(WidgetBuilder builder,
        {String? name}) =>
    PageRouteBuilder<void>(
      settings: RouteSettings(name: name),
      pageBuilder: (context, _, __) => builder(context),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
