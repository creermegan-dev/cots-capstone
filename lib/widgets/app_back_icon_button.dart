import 'package:flutter/material.dart';

/// Icon-only back control shared across the app (tap target, icon, tooltip).
class AppBackIconButton extends StatelessWidget {
  const AppBackIconButton({
    super.key,
    required this.onPressed,
    this.iconColor,
  });

  final VoidCallback onPressed;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? IconTheme.of(context).color;
    return IconButton(
      tooltip: 'Back',
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      icon: Icon(Icons.arrow_back_rounded, size: 22, color: color),
    );
  }
}
