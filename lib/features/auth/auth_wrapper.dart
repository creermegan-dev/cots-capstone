import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/cots_colors.dart';
import '../../core/root_scaffold_messenger.dart';
import '../../providers/auth_provider.dart';
import '../admin/screens/admin_shell_screen.dart';
import '../user/dashboard_screen.dart';
import '../landing/landing_page.dart';

/// Routes guests to [LoginScreen]; signed-in users with `accountRole` admin to
/// [AdminShellScreen]; everyone else to [DashboardScreen].
///
/// Listens to `FirebaseAuth.instance.authStateChanges()` via [AuthProvider].
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

        final wantsAdmin = auth.wantsAdminSession;

        // Firestore `accountRole` admin, or dev email override — see [AuthProvider.effectiveIsAdmin].
        if (auth.effectiveIsAdmin) {
          if (auth.pendingUserPortalSignIn) {
            return const _RejectAdminOnUserPortal();
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (wantsAdmin) auth.clearWantsAdminSession();
            auth.clearPendingUserPortalSignIn();
          });
          return const AdminShellScreen();
        }

        // Used admin login screen but this account is not an admin.
        if (wantsAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            auth.clearWantsAdminSession();
            final messenger = ScaffoldMessenger.maybeOf(context);
            messenger?.showSnackBar(
              const SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: kDangerRed,
                content: Text(
                  'This account is not registered as an admin. Use the regular login for field accounts.',
                ),
              ),
            );
          });
        }

        return const DashboardScreen();
      },
    );
  }
}

/// Signs the user out and explains that admins must use [AdminLoginScreen].
class _RejectAdminOnUserPortal extends StatefulWidget {
  const _RejectAdminOnUserPortal();

  @override
  State<_RejectAdminOnUserPortal> createState() => _RejectAdminOnUserPortalState();
}

class _RejectAdminOnUserPortalState extends State<_RejectAdminOnUserPortal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<AuthProvider>().signOut();
      kRootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: kDangerRed,
          content: Text(
            'Administrator accounts must use Admin login. Tap Login as admin on the login page.',
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: kPrimaryTeal),
      ),
    );
  }
}
