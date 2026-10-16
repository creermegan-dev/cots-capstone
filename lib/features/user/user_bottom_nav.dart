import 'package:flutter/material.dart';

import '../../core/cots_colors.dart';
import 'scan_detection_page.dart';

/// Which tab is highlighted in the shared user bottom navigation.
enum UserNavDestination { dashboard, map, scan, followUp, records, profile }

const userFollowUpRoute = '/user/follow-up';

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
    void open(UserNavDestination destination, Widget Function()? builder) {
      if (_is(destination) || builder == null) return;
      Navigator.of(context)
          .push<void>(MaterialPageRoute<void>(builder: (_) => builder()));
    }

    final items = <Widget>[
      _UserNavItem(
          icon: Icons.home_rounded,
          label: 'Dashboard',
          isActive: _is(UserNavDestination.dashboard),
          onTap: () {
            if (!_is(UserNavDestination.dashboard)) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          }),
      _UserNavItem(
          icon: Icons.location_on_outlined,
          label: 'Map',
          isActive: _is(UserNavDestination.map),
          onTap: () => open(UserNavDestination.map, mapPageBuilder)),
      _ScanNavItem(
          isActive: _is(UserNavDestination.scan),
          onTap: () =>
              open(UserNavDestination.scan, () => const ScanDetectionPage())),
      _UserNavItem(
          icon: Icons.replay_circle_filled_outlined,
          label: 'Follow-up',
          isActive: _is(UserNavDestination.followUp),
          onTap: () {
            if (!_is(UserNavDestination.followUp)) {
              Navigator.of(context).pushNamed(userFollowUpRoute);
            }
          }),
      _UserNavItem(
          icon: Icons.description_outlined,
          label: 'Records',
          isActive: _is(UserNavDestination.records),
          onTap: () => open(UserNavDestination.records, recordsPageBuilder)),
      _UserNavItem(
          icon: Icons.person_outline_rounded,
          label: 'Profile',
          isActive: _is(UserNavDestination.profile),
          onTap: () => open(UserNavDestination.profile, profilePageBuilder)),
    ];
    final scaler = MediaQuery.textScalerOf(context);
    final compactRows =
        scaler.scale(11) > 16 || MediaQuery.sizeOf(context).width < 360;
    final columns = compactRows ? 3 : 6;
    final cellWidth = compactRows
        ? (MediaQuery.sizeOf(context).width - 8) / 3
        : (MediaQuery.sizeOf(context).width - 66) / 6;
    var rowHeight = 64.0;
    for (final label in [
      'Dashboard',
      'Map',
      'Detect',
      'Follow-up',
      'Records',
      'Profile'
    ]) {
      final painter = TextPainter(
        text: TextSpan(
            text: label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 11, height: 1.2, fontWeight: FontWeight.w700)),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout(
          maxWidth: label == 'Detect' && !compactRows ? 50 : cellWidth - 8);
      if (painter.height + 48 > rowHeight) rowHeight = painter.height + 48;
      painter.dispose();
    }
    return BottomAppBar(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      height: rowHeight * (items.length / columns).ceil(),
      elevation: 8,
      shadowColor: Colors.black26,
      color: Colors.white,
      shape: !compactRows && !_is(UserNavDestination.scan)
          ? const CircularNotchedRectangle()
          : null,
      notchMargin: 7,
      child: compactRows
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              for (var start = 0; start < items.length; start += columns)
                SizedBox(
                    height: rowHeight,
                    child: Row(children: [
                      for (final item in items.skip(start).take(columns))
                        Expanded(child: item),
                    ])),
            ])
          : Row(children: [
              Expanded(
                  child: Row(children: [
                for (final item in items.take(2)) Expanded(child: item)
              ])),
              SizedBox(width: 58, child: items[2]),
              Expanded(
                  child: Row(children: [
                for (final item in items.skip(3)) Expanded(child: item)
              ])),
            ]),
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
    return Semantics(
      selected: isActive,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
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
                fontSize: 11,
                height: 1.2,
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
  if (MediaQuery.sizeOf(context).width < 360 ||
      MediaQuery.textScalerOf(context).scale(11) > 16) {
    return const SizedBox.shrink();
  }
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
    child:
        const Icon(Icons.photo_library_rounded, color: Colors.white, size: 30),
  );
}
