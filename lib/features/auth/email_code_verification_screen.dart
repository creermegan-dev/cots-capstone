import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/cots_colors.dart';
import '../../models/pending_email_verification.dart';
import '../../providers/auth_provider.dart';

/// Asks for the one-time code emailed to the account, either on the first
/// sign-in (email verification) or when signing in on a new device.
class EmailCodeVerificationScreen extends StatefulWidget {
  const EmailCodeVerificationScreen({super.key});

  @override
  State<EmailCodeVerificationScreen> createState() =>
      _EmailCodeVerificationScreenState();
}

class _EmailCodeVerificationScreenState
    extends State<EmailCodeVerificationScreen> {
  final _codeCtrl = TextEditingController();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify(AuthProvider auth) async {
    FocusScope.of(context).unfocus();
    try {
      await auth.verifyEmailCode(_codeCtrl.text);
    } catch (_) {
      // The message is shown from auth.lastError.
    }
  }

  Future<void> _resend(AuthProvider auth) async {
    await auth.resendEmailCode();
    if (!mounted || auth.lastError != null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: kDarkTeal,
        content: Text('A new code was sent. Use the newest email.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pending = auth.pendingEmailVerification;
    if (pending == null) return const SizedBox.shrink();

    final firstLogin = pending.reason == EmailVerificationReason.firstLogin;
    final wait = pending.secondsUntilResend(DateTime.now());
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    firstLogin
                        ? Icons.mark_email_unread_outlined
                        : Icons.phonelink_lock_outlined,
                    size: 56,
                    color: kPrimaryTeal,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    firstLogin ? 'Verify your email' : 'Verify this device',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: kDarkTeal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    firstLogin
                        ? 'Enter the code we emailed to ${pending.email} when '
                            'you created your account. You only need to do '
                            'this once.'
                        : 'For your security, we emailed a code to '
                            '${pending.email}. Enter it to trust this device. '
                            'You will not be asked again on this device.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kMutedGray, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _codeCtrl,
                    autofocus: true,
                    enabled: !auth.isBusy,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 10,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: 6,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Email code',
                      counterText: '',
                      errorText: auth.lastError,
                      errorMaxLines: 4,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _verify(auth),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: auth.isBusy ? null : () => _verify(auth),
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrimaryTeal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(auth.isBusy ? 'Verifying...' : 'Verify'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: auth.isBusy || wait > 0
                        ? null
                        : () => _resend(auth),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimaryTeal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      wait > 0 ? 'Send new code in ${wait}s' : 'Send new code',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: auth.isBusy
                        ? null
                        : () => auth.cancelEmailVerification(),
                    child: const Text('Cancel and sign out'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Not in your inbox? Check Spam. Codes expire, so use the '
                    'newest email.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kMutedGray, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
