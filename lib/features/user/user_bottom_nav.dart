import 'package:flutter/material.dart';
import '../../core/cots_theme.dart';

import 'scan_detection_page.dart';

/// Which tab is highlighted in the shared user bottom navigation.
enum UserNavDestination { dashboard, map, scan, followUp, records, profile }

const userFollowUpRoute = '/user/follow-up';

/// Marine navigation tokens with clear, restrained active states.
const Color _kCockpitNavy = Colors.white;
const Color _kCockpitCyan = CotsUi.primary;
const Color _kCockpitMuted = CotsUi.secondaryText;
const Color _kCockpitActiveBg = CotsUi.primaryTint;

/// Bottom app bar + notch used on Dashboard, Map, Scan, Records, and Profile.
/// Preserves the field workflow with a quiet, readable navigation surface.
class UserBottomNavBar extends StatelessWidget {
  const UserBottomNavBar({
    super.key,
    required this.active,
    required this.mapPageBuilder,
    this.recordsPageBuilder,
    this.profilePageBuilder,
  });

  /// Pass `null` when no tab should appear selected (e.g. Notifications).
  final UserNavDestination? active;
  final Widget Function() mapPageBuilder;

  /// Avoids circular imports; defaults to a no-op if omitted.
  final Widget Function()? recordsPageBuilder;

  /// Avoids circular imports; defaults to a no-op if omitted.
  final Widget Function()? profilePageBuilder;

  bool _is(UserNavDestination d) => active == d;

  @override
  Widget build(BuildContext context) {
    void open(UserNavDestination destination, Widget Function()? builder) {
      if (_is(destination) || builder == null) return;
      Navigator.of(context)
          .push<void>(MaterialPageRoute<void>(builder: (_) => builder()));
    }

    final leftItems = <Widget>[
      _CockpitNavItem(
        icon: Icons.grid_view_rounded,
        label: 'Dashboard',
        isActive: _is(UserNavDestination.dashboard),
        onTap: () {
          if (!_is(UserNavDestination.dashboard)) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
      ),
      _CockpitNavItem(
        icon: Icons.explore_outlined,
        label: 'Map',
        isActive: _is(UserNavDestination.map),
        onTap: () => open(UserNavDestination.map, mapPageBuilder),
      ),
    ];

    final rightItems = <Widget>[
      _CockpitNavItem(
        icon: Icons.assignment_outlined,
        label: 'Records',
        isActive:
            _is(UserNavDestination.records) || _is(UserNavDestination.followUp),
        onTap: () => open(UserNavDestination.records, recordsPageBuilder),
      ),
      _CockpitNavItem(
        icon: Icons.person_outline_rounded,
        label: 'Profile',
        isActive: _is(UserNavDestination.profile),
        onTap: () => open(UserNavDestination.profile, profilePageBuilder),
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: _kCockpitNavy,
        border: Border(
          top: BorderSide(color: CotsUi.divider, width: 0.75),
        ),
      ),
      child: BottomAppBar(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        height: 68,
        elevation: 0,
        color: Colors.transparent,
        shape: !_is(UserNavDestination.scan)
            ? const CircularNotchedRectangle()
            : null,
        notchMargin: 8,
        // The bar has a fixed height: keep its labels at normal size even
        // with large system text, so nothing overflows.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.0,
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    for (final item in leftItems) Expanded(child: item),
                  ],
                ),
              ),
              // Reserved center space for the docked FAB
              SizedBox(
                width: 64,
                child: _CockpitCenterScanItem(
                  isActive: _is(UserNavDestination.scan),
                  onTap: () => open(
                    UserNavDestination.scan,
                    () => const ScanDetectionPage(),
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    for (final item in rightItems) Expanded(child: item),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CockpitNavItem extends StatelessWidget {
  const _CockpitNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _kCockpitCyan : _kCockpitMuted;
    return Semantics(
      selected: isActive,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: _kCockpitCyan.withValues(alpha: 0.15),
        highlightColor: _kCockpitCyan.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? _kCockpitActiveBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.15,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CockpitCenterScanItem extends StatelessWidget {
  const _CockpitCenterScanItem({
    required this.isActive,
    required this.onTap,
  });

  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Scan & Detect',
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const SizedBox(height: 38),
            Text(
              'Detect',
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w600,
                color: isActive ? _kCockpitCyan : _kCockpitMuted,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}

/// Primary camera action for field-monitoring screens.
Widget userShellScanFab(
  BuildContext context, {
  Color? backgroundColor,
}) {
  return Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: FloatingActionButton(
      onPressed: () {
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (context) => const ScanDetectionPage(),
          ),
        );
      },
      elevation: 0,
      backgroundColor: backgroundColor ?? CotsUi.primary,
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor ?? CotsUi.primary,
        ),
        child: const Icon(
          Icons.camera_alt_rounded,
          color: Colors.white,
          size: 27,
        ),
      ),
    ),
  );
}
