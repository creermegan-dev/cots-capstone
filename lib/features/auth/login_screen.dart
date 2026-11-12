import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/cots_colors.dart';
import '../../core/remembered_login.dart';
import '../../core/secure_supabase_local_storage.dart';
import '../../providers/auth_provider.dart';
import 'auth_navigation.dart';
import 'auth_routes.dart';
import 'password_recovery_screen.dart';
import 'widgets/auth_layout.dart';
import 'widgets/auth_responsive_scaffold.dart';
import 'widgets/cots_auth_password_field.dart';
import 'widgets/cots_auth_text_field.dart';
import 'widgets/cots_gradient_primary_button.dart';

/// Login screen connected through [AuthProvider].
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _rememberMe = true;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    // Show the person's last choice.
    SecureSupabaseLocalStorage.rememberSession().then((remember) {
      if (mounted) setState(() => _rememberMe = remember);
    });
    // Fill in the email saved by "Remember me", unless the person has
    // already started typing.
    RememberedLogin.email().then((email) {
      if (mounted && email.isNotEmpty && _emailCtrl.text.isEmpty) {
        _emailCtrl.text = email;
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter your email';
    if (!_emailRegex.hasMatch(s)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Enter your password';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    auth.clearLastError();

    if (auth.usesSupabase) {
      try {
        await SecureSupabaseLocalStorage.setRememberSession(_rememberMe);
      } catch (_) {
        // Storage failure only affects auto sign-out; sign-in can continue.
      }
      if (!mounted) return;
    }

    try {
      await auth.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      // The password was accepted: remember (or forget) the email.
      await RememberedLogin.save(
        email: _emailCtrl.text,
        remember: _rememberMe,
      );
      if (!mounted) return;

      if (auth.pendingEmailVerification != null) {
        // The root shows the email-code screen (first sign-in or new device).
        _passwordCtrl.clear();
        resetToAuthRoot(context);
        return;
      }

      final profileReady = await _waitForProfile(auth);
      if (!mounted) return;

      if (!profileReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: kDangerRed,
            content: Text(
              auth.lastError ??
                  'Signed in, but your profile could not be loaded.',
            ),
          ),
        );
        return;
      }

      resetToAuthRoot(context);
    } catch (_) {
      if (!mounted) return;
      if (auth.requiresTotpCode) {
        final verified = await _promptTotpCode(auth);
        if (!mounted || !verified) return;
        final profileReady = await _waitForProfile(auth);
        if (!mounted) return;
        if (profileReady) {
          resetToAuthRoot(context);
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: kDangerRed,
          content: Text(auth.lastError ?? 'Sign in failed.'),
        ),
      );
    }
  }

  Future<bool> _promptTotpCode(AuthProvider auth) async {
    final controller = TextEditingController();
    String? errorText;
    var submitting = false;
    try {
      return await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: const Text('Two-factor verification'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Authenticator code',
                    hintText: '123456',
                    errorText: errorText,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () {
                            auth.cancelTotpSignIn();
                            Navigator.pop(dialogContext, false);
                          },
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            setDialogState(() {
                              submitting = true;
                              errorText = null;
                            });
                            try {
                              await auth.completeTotpSignIn(controller.text);
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext, true);
                              }
                            } catch (_) {
                              if (!dialogContext.mounted) return;
                              setDialogState(() {
                                submitting = false;
                                errorText = auth.lastError ??
                                    'The code is invalid or expired.';
                              });
                            }
                          },
                    child: Text(submitting ? 'Verifying...' : 'Verify'),
                  ),
                ],
              ),
            ),
          ) ??
          false;
    } finally {
      controller.dispose();
    }
  }

  Future<bool> _waitForProfile(AuthProvider auth) async {
    for (var attempt = 0; attempt < 80; attempt++) {
      if (!auth.isLoadingProfile) {
        return auth.userModel != null;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return auth.userModel != null;
  }

  Future<void> _forgotPassword() async {
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    if (auth.usesSupabase) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PasswordRecoveryScreen(initialEmail: _emailCtrl.text),
        ),
      );
      return;
    }
    var email = _emailCtrl.text.trim();

    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      email = await _promptEmailDialog() ?? '';
      if (email.isEmpty) return;
    }

    if (!mounted) return;
    auth.clearLastError();

    try {
      await auth.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: kDarkTeal,
          content: Text('Password reset email sent to $email'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: kDangerRed,
          content: Text(auth.lastError ?? 'Could not send reset email.'),
        ),
      );
    }
  }

  Future<String?> _promptEmailDialog() async {
    final controller = TextEditingController(text: _emailCtrl.text.trim());
    final formKey = GlobalKey<FormState>();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Reset password'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                ),
                validator: _validateEmail,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.pop(ctx, controller.text.trim());
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: kPrimaryTeal),
                child: const Text('Send link'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  void _goSignUp() {
    Navigator.of(context).pushNamed(AuthRoutes.signup);
  }

  void _goLanding() {
    resetToAuthRoot(context);
  }

  Widget _buildRememberRow(AuthProvider auth) {
    final desktop = authUseDesktopFields(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CheckboxTheme(
          data: CheckboxThemeData(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            side: BorderSide(
              color: desktop ? AuthTokens.focusTeal : kPrimaryTeal,
              width: 1.5,
            ),
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return desktop ? AuthTokens.focusTeal : kPrimaryTeal;
              }
              return Colors.transparent;
            }),
            checkColor: WidgetStateProperty.all(Colors.white),
          ),
          child: SizedBox(
            height: 48,
            width: 48,
            child: Checkbox(
              value: _rememberMe,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              onChanged: (v) => setState(() => _rememberMe = v ?? false),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _rememberMe = !_rememberMe),
            behavior: HitTestBehavior.opaque,
            child: Tooltip(
              message: 'Remember your email and stay signed in after closing '
                  'the app. Untick it on shared devices.',
              child: Text(
                'Remember me',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: desktop ? AuthTokens.titleNavy : kTextNavy,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ),
        ),
        Flexible(
          child: TextButton(
            onPressed: auth.isBusy ? null : _forgotPassword,
            style: TextButton.styleFrom(
              foregroundColor: AuthTokens.focusTeal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Forgot Password?',
              style: TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFields(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CotsAuthTextField(
          controller: _emailCtrl,
          label: 'Email Address',
          hint: 'Enter your email',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          validator: _validateEmail,
        ),
        SizedBox(height: authUseDesktopFields(context) ? 20 : 18),
        CotsAuthPasswordField(
          controller: _passwordCtrl,
          label: 'Password',
          hint: 'Enter your password',
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          validator: _validatePassword,
          onFieldSubmitted: (_) => _submit(),
        ),
        SizedBox(height: authUseDesktopFields(context) ? 16 : 14),
        _buildRememberRow(auth),
        SizedBox(height: authUseDesktopFields(context) ? 24 : 18),
        CotsGradientPrimaryButton(
          label: 'Login',
          isLoading: auth.isBusy,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _buildFooter(AuthProvider auth) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Don’t have an account? ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: authUseDesktopFields(context)
                    ? AuthTokens.subtitleGray
                    : kMutedGray,
              ),
        ),
        GestureDetector(
          onTap: auth.isBusy ? null : _goSignUp,
          child: Text(
            'Sign Up',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AuthTokens.focusTeal,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isMobile = authLayoutModeOf(context) == AuthLayoutMode.mobile;

    final form = Form(
      key: _formKey,
      child: isMobile
          ? AuthMobileFormCard(child: _buildFields(auth))
          : _buildFields(auth),
    );

    return AuthResponsiveScaffold(
      mobileAppBarTitle: 'Login',
      onBackToLanding: auth.isBusy ? null : _goLanding,
      mobileHeader: const AuthMobileHeader(),
      desktopHeader: const AuthCardHeader(
        showLogo: false,
        title: 'Welcome back',
        subtitle: 'Sign in to continue monitoring and protecting coral reefs.',
      ),
      formChild: form,
      footer: _buildFooter(auth),
    );
  }
}
