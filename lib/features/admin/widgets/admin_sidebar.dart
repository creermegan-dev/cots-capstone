import 'package:flutter/material.dart';

import '../layout/admin_nav_entries.dart';
import '../layout/admin_shell_search_bar.dart';
import '../models/admin_nav_models.dart';
import '../theme/admin_theme.dart';
import 'admin_sidebar_nav_tile.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
    this.width = 268,
    this.compact = false,
    this.showRailToggle = false,
    this.railCollapsed = false,
    this.onToggleRail,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final double width;
  final bool compact;
  final bool showRailToggle;
  final bool railCollapsed;
  final VoidCallback? onToggleRail;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: width,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AdminColors.sidebarTop,
              AdminColors.sidebarBottom,
              Color(0xFF0D2238),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.8, -0.9),
                    radius: 1.2,
                    colors: [
                      AdminColors.sidebarAccentGlow,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(compact ? 10 : 20, compact ? 16 : 28, compact ? 10 : 20, compact ? 10 : 20),
                  child: compact
                      ? Column(
                          children: [
                            if (showRailToggle && onToggleRail != null)
                              IconButton(
                                tooltip: 'Expand menu',
                                onPressed: onToggleRail,
                                icon: const Icon(
                                  Icons.keyboard_double_arrow_right_rounded,
                                  color: Colors.white70,
                                ),
                              ),
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF26A69A), Color(0xFF00897B)],
                                ),
                              ),
                              child: const Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(Icons.waves_rounded, color: Colors.white54, size: 22),
                                  Icon(Icons.star_rounded, color: Color(0xFFFF7043), size: 20),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showRailToggle && onToggleRail != null) ...[
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                tooltip: 'Collapse to icons',
                                onPressed: onToggleRail,
                                icon: const Icon(Icons.keyboard_double_arrow_left_rounded, color: Colors.white70),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF26A69A), Color(0xFF00897B)],
                                ),
                              ),
                              child: const Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(Icons.waves_rounded, color: Colors.white54, size: 22),
                                  Icon(Icons.star_rounded, color: Color(0xFFFF7043), size: 20),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'COTS MONITORING SYSTEM',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.95),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5,
                                      letterSpacing: 0.6,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Admin Panel',
                                    style: TextStyle(
                                      color: Colors.cyanAccent.withValues(alpha: 0.65),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
                if (!compact) const AdminShellSearchBar(padding: EdgeInsets.fromLTRB(20, 0, 20, 8)),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: kAdminNavEntries.length,
                    itemBuilder: (context, i) {
                      final e = kAdminNavEntries[i];
                      if (e is AdminNavSectionHeader) {
                        if (compact) return const SizedBox(height: 8);
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(22, 14, 16, 8),
                          child: Text(
                            e.title,
                            style: TextStyle(
                              color: AdminColors.navText.withValues(alpha: 0.55),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        );
                      }
                      if (e is AdminNavItemData) {
                        return AdminSidebarNavTile(
                          icon: e.icon,
                          label: e.label,
                          badge: e.badge,
                          selected: selectedIndex == e.index,
                          compact: compact,
                          onTap: () => onSelect(e.index),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                if (compact)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        child: const Icon(Icons.person_rounded, color: Colors.white70, size: 20),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          child: const Icon(Icons.person_rounded, color: Colors.white70),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Admin User',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Super Administrator',
                                style: TextStyle(
                                  color: Colors.cyanAccent.withValues(alpha: 0.55),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(compact ? 8 : 12, 0, compact ? 8 : 12, compact ? 12 : 20),
                  child: AdminSidebarNavTile(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    selected: false,
                    compact: compact,
                    onTap: onLogout,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
