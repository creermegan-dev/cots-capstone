import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';
import '../widgets/admin_sidebar.dart';
import 'admin_breakpoints.dart';
import 'admin_desk_top_bar.dart';
import 'admin_mobile_drawer.dart';
import 'admin_shell_app_bar.dart';

/// Responsive shell: [Drawer] + [AppBar] on mobile; collapsible sidebar on tablet; full sidebar on desktop.
class AdminResponsiveChrome extends StatefulWidget {
  const AdminResponsiveChrome({
    super.key,
    required this.selectedNavIndex,
    required this.onNavSelect,
    required this.onLogout,
    required this.pageTitle,
    required this.body,
    this.navBadgeFor,
    this.showDeskTopBar = true,
    this.showBackButton = false,
    this.onBack,
  });

  final int selectedNavIndex;
  final ValueChanged<int> onNavSelect;
  final VoidCallback onLogout;
  final String pageTitle;
  final Widget body;
  /// Dynamic nav badge counts keyed by [AdminNavItemData.index].
  final int? Function(int navIndex)? navBadgeFor;
  final bool showDeskTopBar;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  State<AdminResponsiveChrome> createState() => _AdminResponsiveChromeState();
}

class _AdminResponsiveChromeState extends State<AdminResponsiveChrome> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final mobile = AdminBreakpoints.isMobileWidth(w);
        final tablet = AdminBreakpoints.isTabletWidth(w);

        if (mobile) {
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: AdminColors.contentBg,
            drawer: AdminMobileDrawer(
              selectedIndex: widget.selectedNavIndex,
              onSelect: widget.onNavSelect,
              onLogout: widget.onLogout,
              badgeFor: widget.navBadgeFor,
            ),
            appBar: AdminShellAppBar(
              title: widget.pageTitle,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
              showMenuButton: !widget.showBackButton,
              showBackButton: widget.showBackButton,
              onBack: widget.onBack,
            ),
            body: ColoredBox(
              color: AdminColors.contentBg,
              child: bodyScrollSafe(widget.body),
            ),
          );
        }

        final rail = tablet && _sidebarCollapsed;
        final sidebarWidth = rail ? 76.0 : 268.0;
        final showDeskTitleStrip = widget.showDeskTopBar &&
            !AdminBreakpoints.isDesktopWidth(w);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminSidebar(
              selectedIndex: widget.selectedNavIndex,
              onSelect: widget.onNavSelect,
              onLogout: widget.onLogout,
              badgeFor: widget.navBadgeFor,
              width: sidebarWidth,
              compact: rail,
              showRailToggle: tablet,
              railCollapsed: _sidebarCollapsed,
              onToggleRail: tablet
                  ? () => setState(() => _sidebarCollapsed = !_sidebarCollapsed)
                  : null,
            ),
            Expanded(
              child: ColoredBox(
                color: AdminColors.contentBg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showDeskTitleStrip)
                      AdminDeskTopBar(title: widget.pageTitle),
                    Expanded(child: bodyScrollSafe(widget.body)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Avoid nested scroll issues: if [body] is already scrollable, use as-is.
  static Widget bodyScrollSafe(Widget body) {
    return body;
  }
}
