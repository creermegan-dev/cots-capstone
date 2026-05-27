import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/cots_colors.dart';
import '../../providers/auth_provider.dart';
import 'auth_routes.dart';
import 'widgets/cots_auth_logo_badge.dart';
import 'widgets/cots_auth_password_field.dart';
import 'widgets/cots_auth_text_field.dart';
import 'widgets/cots_gradient_primary_button.dart';
import 'widgets/ocean_background.dart';

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
    auth.beginUserPortalSignInAttempt();
    auth.clearLastError();
    auth.setWantsAdminSession(false);

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

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      auth.clearPendingUserPortalSignIn();
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Login',
          style: TextStyle(
            color: kDarkTeal,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: OceanBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomInset),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const CotsAuthLogoBadge(),
                  const SizedBox(height: 16),
                  Text(
                    'COTS Monitor',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: kDarkTeal,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Crown-of-Thorns Starfish Monitoring',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: kMutedGray,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 28),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                      child: Column(
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
                          const SizedBox(height: 18),
                          CotsAuthPasswordField(
                            controller: _passwordCtrl,
                            label: 'Password',
                            hint: 'Enter your password',
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            validator: _validatePassword,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CheckboxTheme(
                                data: CheckboxThemeData(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  side: const BorderSide(color: kPrimaryTeal, width: 1.5),
                                  fillColor: WidgetStateProperty.resolveWith((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return kPrimaryTeal;
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
                                    onChanged: (v) =>
                                        setState(() => _rememberMe = v ?? false),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _rememberMe = !_rememberMe),
                                  behavior: HitTestBehavior.opaque,
                                  child: Tooltip(
                                    message:
                                        'Firebase keeps you signed in on this device; use Sign out from the home screen to leave your account.',
                                    child: Text(
                                      'Remember me',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: kTextNavy,
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
                                    foregroundColor: kPrimaryTeal,
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
                          ),
                          const SizedBox(height: 18),
                          CotsGradientPrimaryButton(
                            label: 'Login',
                            isLoading: auth.isBusy,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Don’t have an account? ',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: kMutedGray,
                            ),
                      ),
                      GestureDetector(
                        onTap: auth.isBusy ? null : _goSignUp,
                        child: Text(
                          'Sign Up',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: kPrimaryTeal,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton(
                      onPressed: auth.isBusy
                          ? null
                          : () => Navigator.of(context).pushNamed(AuthRoutes.adminLogin),
                      child: Text(
                        'Login as admin',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: kDarkTeal,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: kDarkTeal.withValues(alpha: 0.5),
                            ),
                      ),
                    ),
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
