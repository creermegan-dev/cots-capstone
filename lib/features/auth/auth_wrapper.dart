import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/cots_colors.dart';
import '../../providers/auth_provider.dart';
import '../admin/screens/admin_shell_screen.dart';
import '../user/dashboard_screen.dart';
import '../landing/landing_page.dart';

/// Routes guests to [LandingPage]; signed-in admins to [AdminShellScreen];
/// field users to [DashboardScreen].
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isAuthenticated) {
          return const LandingPage();
        }

        if (auth.isLoadingProfile) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: kPrimaryTeal),
            ),
          );
        }

        if (auth.userModel == null) {
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    const Icon(Icons.cloud_off_outlined, size: 56, color: kMutedGray),
                    const SizedBox(height: 16),
                    Text(
                      'Profile unavailable',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: kDarkTeal,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      auth.lastError ??
                          'Your account exists but no Firestore profile was found.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kMutedGray),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => auth.refreshProfile(),
                      style: FilledButton.styleFrom(
                        backgroundColor: kPrimaryTeal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Retry'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: auth.isBusy ? null : () => auth.signOut(),
                      child: const Text('Sign out'),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          );
        }

        if (auth.effectiveIsAdmin) {
          return const AdminShellScreen();
        }

        return const DashboardScreen();
      },
    );
  }
}
