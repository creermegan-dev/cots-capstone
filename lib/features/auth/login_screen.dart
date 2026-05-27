import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/cots_colors.dart';
import '../../providers/auth_provider.dart';
import 'auth_navigation.dart';
import 'auth_routes.dart';
import 'widgets/auth_layout.dart';
import 'widgets/auth_responsive_scaffold.dart';
import 'widgets/cots_auth_password_field.dart';
import 'widgets/cots_auth_text_field.dart';
import 'widgets/cots_gradient_primary_button.dart';

/// Login screen — connects to [AuthProvider] / Firebase Auth.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _rememberMe = false;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

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

    try {
      await auth.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;

      final profileReady = await _waitForProfile(auth);
      if (!mounted) return;

      if (!profileReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: kDangerRed,
            content: Text(
              auth.lastError ??
                  'Signed in, but your Firestore profile could not be loaded.',
            ),
          ),
        );
        return;
      }

      resetToAuthRoot(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: kDangerRed,
          content: Text(auth.lastError ?? 'Sign in failed.'),
        ),
      );
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
    var email = _emailCtrl.text.trim();

    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      email = await _promptEmailDialog() ?? '';
      if (email.isEmpty) return;
    }

    if (!mounted) return;
    final auth = context.read<AuthProvider>();
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
              message:
                  'Firebase keeps you signed in on this device; use Sign out from the home screen to leave your account.',
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
    return Column(
      children: [
        Wrap(
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
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: auth.isBusy ? null : _goLanding,
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Back to Landing'),
          style: TextButton.styleFrom(
            foregroundColor: AuthTokens.focusTeal,
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
      mobileHeader: const AuthMobileHeader(),
      desktopHeader: const AuthCardHeader(
        title: 'Welcome back',
        subtitle: 'Sign in to continue monitoring and protecting coral reefs.',
      ),
      formChild: form,
      footer: _buildFooter(auth),
    );
  }
}
