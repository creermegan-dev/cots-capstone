import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';
import 'admin_breakpoints.dart';

/// Light top strip on tablet/desktop: page title only (search lives in the sidebar).
class AdminDeskTopBar extends StatelessWidget {
  const AdminDeskTopBar({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final w = AdminBreakpoints.widthOf(context);
    final tight = w < AdminBreakpoints.desktop;

    return Material(
      color: AdminColors.cardWhite,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(tight ? 14 : 20, 10, tight ? 14 : 20, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: tight ? 17 : 19,
                  color: AdminColors.headerTitle,
                ),
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: AdminColors.muted.withValues(alpha: 0.12)),
        ],
      ),
    );
  }
}
