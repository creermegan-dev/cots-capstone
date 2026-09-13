import 'package:flutter/material.dart';

import '../models/admin_nav_models.dart';
import '../theme/admin_theme.dart';
import 'admin_nav_entries.dart';
import 'admin_shell_search_bar.dart';

/// Full-width drawer navigation for mobile admin layout.
class AdminMobileDrawer extends StatelessWidget {
  const AdminMobileDrawer({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
    this.badgeFor,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final int? Function(int navIndex)? badgeFor;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width.clamp(280.0, 320.0),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AdminColors.sidebarTop,
              AdminColors.sidebarBottom,
              Color(0xFF0D2238),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'COTS Monitor',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const AdminShellSearchBar(padding: EdgeInsets.fromLTRB(16, 0, 16, 8)),
              const Divider(height: 1, color: Colors.white12),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  itemCount: kAdminNavEntries.length,
                  itemBuilder: (context, i) {
                    final e = kAdminNavEntries[i];
                    if (e is AdminNavSectionHeader) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
                        child: Text(
                          e.title,
                          style: TextStyle(
                            color: AdminColors.navText.withValues(alpha: 0.55),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      );
                    }
                    if (e is AdminNavItemData) {
                      final sel = selectedIndex == e.index;
                      final badge = badgeFor?.call(e.index);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        child: ListTile(
                          leading: Icon(
                            e.icon,
                            color: sel ? AdminColors.navTextActive : AdminColors.navText,
                          ),
                          title: Text(
                            e.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: sel ? AdminColors.navTextActive : AdminColors.navText,
                            ),
                          ),
                          trailing: badge != null && badge > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$badge',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              : null,
                          selected: sel,
                          selectedTileColor: AdminColors.navActive.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onTap: () {
                            Navigator.of(context).pop();
                            onSelect(e.index);
                          },
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                          Text(
                            'Admin User',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
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
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.white70),
                title: const Text('Logout', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.of(context).pop();
                  onLogout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
