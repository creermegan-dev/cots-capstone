import 'package:flutter/material.dart';

import '../../core/cots_colors.dart';
import 'scan_detection_page_v2.dart';

/// Which tab is highlighted in the shared user bottom navigation.
enum UserNavDestination { dashboard, map, scan, records, profile }

/// Bottom app bar + notch used on Dashboard, Map, Scan, Records, and Profile.
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
    final onScanPage = _is(UserNavDestination.scan);

    return BottomAppBar(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      height: 64,
      elevation: 8,
      shadowColor: Colors.black26,
      color: Colors.white,
      shape: onScanPage ? null : const CircularNotchedRectangle(),
      notchMargin: onScanPage ? 0 : 7,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _UserNavItem(
            icon: Icons.home_rounded,
            label: 'Dashboard',
            isActive: _is(UserNavDestination.dashboard),
            onTap: () {
              if (_is(UserNavDestination.dashboard)) return;
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
          _UserNavItem(
            icon: Icons.location_on_outlined,
            label: 'Map',
            isActive: _is(UserNavDestination.map),
            onTap: () {
              if (_is(UserNavDestination.map)) return;
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => mapPageBuilder(),
                ),
              );
            },
          ),
          _ScanNavItem(
            isActive: onScanPage,
            onTap: () {
              if (onScanPage) return;
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => const ScanDetectionPage(),
                ),
              );
            },
          ),
          _UserNavItem(
            icon: Icons.description_outlined,
            label: 'Records',
            isActive: _is(UserNavDestination.records),
            onTap: () {
              if (_is(UserNavDestination.records)) return;
              final buildRecords = recordsPageBuilder;
              if (buildRecords == null) return;
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => buildRecords(),
                ),
              );
            },
          ),
          _UserNavItem(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            isActive: _is(UserNavDestination.profile),
            onTap: () {
              if (_is(UserNavDestination.profile)) return;
              final buildProfile = profilePageBuilder;
              if (buildProfile == null) return;
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => buildProfile(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UserNavItem extends StatelessWidget {
  const _UserNavItem({
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
    final color = isActive ? kPrimaryTeal : kMutedGray;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanNavItem extends StatelessWidget {
  const _ScanNavItem({
    required this.isActive,
    required this.onTap,
  });

  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.white : kMutedGray;
    final bg = isActive ? kPrimaryTeal : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: kPrimaryTeal.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.photo_library_rounded,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Detect',
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? kPrimaryTeal : kMutedGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Center FAB on shell screens (opens New Detection / GoPro image flow).
Widget userShellScanFab(
  BuildContext context, {
  Color backgroundColor = kDarkTeal,
}) {
  return FloatingActionButton.large(
    onPressed: () {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => const ScanDetectionPage(),
        ),
      );
    },
    elevation: 4,
    backgroundColor: backgroundColor,
    shape: const CircleBorder(),
    child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 30),
  );
}
