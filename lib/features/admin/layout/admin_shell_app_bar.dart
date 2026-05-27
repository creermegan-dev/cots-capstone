import 'package:cots_monitor/widgets/app_back_icon_button.dart';
import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

/// Mobile-first app bar: menu, optional back, title.
class AdminShellAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AdminShellAppBar({
    super.key,
    required this.title,
    this.onMenuTap,
    this.showMenuButton = true,
    this.showBackButton = false,
    this.onBack,
  });

  final String title;
  final VoidCallback? onMenuTap;
  final bool showMenuButton;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: AdminColors.cardWhite,
      foregroundColor: AdminColors.headerTitle,
      leading: showBackButton
          ? AppBackIconButton(
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              iconColor: AdminColors.headerTitle,
            )
          : showMenuButton
              ? IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: onMenuTap,
                )
              : null,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
      ),
    );
  }
}
