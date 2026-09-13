import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/cots_colors.dart';
import '../../providers/auth_provider.dart';
import 'auth_wrapper.dart';

/// Clears the nav stack and returns to [AuthWrapper], which routes guests to the
/// landing page and signed-in users to the correct dashboard.
void resetToAuthRoot(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const AuthWrapper()),
    (_) => false,
  );
}

/// Shows a confirmation dialog, signs out, and returns to the landing page.
Future<void> confirmAndSignOut(
  BuildContext context, {
  bool showSuccessSnackBar = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Log out?',
        style: TextStyle(fontWeight: FontWeight.w700, color: kDarkTeal),
      ),
      content: const Text(
        'Are you sure you want to log out? You will be returned to the landing page.',
        style: TextStyle(color: kMutedGray, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: kPrimaryTeal,
            foregroundColor: Colors.white,
          ),
          child: const Text('Yes, log out'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  await context.read<AuthProvider>().signOut();
  if (!context.mounted) return;

  resetToAuthRoot(context);

  if (showSuccessSnackBar && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed out successfully.')),
    );
  }
}
