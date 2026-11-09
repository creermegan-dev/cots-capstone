import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

/// Safe fallback for an unknown admin navigation index.
class AdminPlaceholderScreen extends StatefulWidget {
  const AdminPlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  State<AdminPlaceholderScreen> createState() => _AdminPlaceholderScreenState();
}

class _AdminPlaceholderScreenState extends State<AdminPlaceholderScreen> {
  int _refreshGeneration = 0;

  void _onRefresh() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Refreshed.'),
      ),
    );
    setState(() => _refreshGeneration++);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      key: ValueKey<int>(_refreshGeneration),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction_rounded, size: 56, color: AdminColors.muted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AdminColors.headerTitle,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'UI shell ready — connect data and actions here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AdminColors.muted.withValues(alpha: 0.9)),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _onRefresh,
              icon: AdminDateTimeTokens.refreshIcon,
              label: const Text('Refresh', style: AdminDateTimeTokens.refreshChipTextStyle),
              style: AdminDateTimeTokens.refreshOutlinedButtonStyle(),
            ),
          ],
        ),
      ),
    );
  }
}
