import 'package:cots_monitor/widgets/app_back_icon_button.dart';
import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

/// Icon-only back control for admin detail headers (uniform tap target and styling).
class AdminBackIconButton extends StatelessWidget {
  const AdminBackIconButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppBackIconButton(
      onPressed: onPressed,
      iconColor: AdminColors.headerTitle,
    );
  }
}
