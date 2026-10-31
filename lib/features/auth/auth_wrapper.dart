import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/cots_colors.dart';
import '../../core/supabase_auth_callback.dart';
import '../../providers/auth_provider.dart';
import '../../services/offline_submission_service.dart';
import '../../services/push_notification_service.dart';
import '../expert/screens/expert_shell_screen.dart';
import '../admin/screens/admin_shell_screen.dart';
import '../user/dashboard_screen.dart';
import '../landing/landing_page.dart';
import 'auth_navigation.dart';
import 'email_code_verification_screen.dart';
import '../../widgets/cots_loading_skeleton.dart';

/// Routes guests to [LandingPage]; experts to [ExpertShellScreen]; admins to
/// [AdminShellScreen]; field users to [DashboardScreen].
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        unawaited(
          OfflineSubmissionService.instance.setActiveUser(auth.userModel?.uid),
        );
        unawaited(
          PushNotificationService.instance.setActiveUser(auth.userModel?.uid),
        );
        final Widget destination;
        if (auth.pendingEmailVerification != null) {
          destination = const EmailCodeVerificationScreen();
        } else if (!auth.isAuthenticated) {
          destination = const LandingPage();
        } else if (auth.isLoadingProfile) {
          destination = const Scaffold(
            body: CotsPageLoading(
                layout: CotsSkeletonLayout.profile, label: 'Loading account'),
          );
        } else if (auth.userModel == null) {
          destination = Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    const Icon(Icons.cloud_off_outlined,
                        size: 56, color: kMutedGray),
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
                          'Your account exists but its profile could not be loaded.',
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
                      onPressed:
                          auth.isBusy ? null : () => confirmAndSignOut(context),
                      child: const Text('Sign out'),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          );
        } else if (auth.effectiveIsExpert) {
          destination = const ExpertShellScreen();
        } else if (auth.effectiveIsAdmin) {
          destination = const AdminShellScreen();
        } else {
          destination = const DashboardScreen();
        }

        return _ConfirmationOverlay(
          notice: auth.signupConfirmationNotice,
          onDismiss: auth.clearSignupConfirmationNotice,
          child: destination,
        );
      },
    );
  }
}

class _ConfirmationOverlay extends StatelessWidget {
  const _ConfirmationOverlay({
    required this.notice,
    required this.onDismiss,
    required this.child,
  });

  final SupabaseConfirmationNotice? notice;
  final VoidCallback onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final current = notice;
    if (current == null) return child;

    final isProcessing = current.phase == SupabaseConfirmationPhase.processing;
    final isConfirmed = current.phase == SupabaseConfirmationPhase.confirmed;
    final color = isConfirmed
        ? Colors.green.shade700
        : isProcessing
            ? kPrimaryTeal
            : kDangerRed;

    return Stack(
      children: [
        child,
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              elevation: 8,
              color: color,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    if (isProcessing)
                      const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(
                        isConfirmed
                            ? Icons.mark_email_read_outlined
                            : Icons.error_outline,
                        color: Colors.white,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        current.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!isProcessing)
                      IconButton(
                        tooltip: 'Dismiss',
                        onPressed: onDismiss,
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
