import 'package:cots_monitor/widgets/app_back_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/cots_colors.dart';
import '../../core/root_scaffold_messenger.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import 'widgets/cots_auth_dropdown.dart';
import 'widgets/cots_auth_logo_badge.dart';
import 'widgets/cots_auth_password_field.dart';
import 'widgets/cots_auth_text_field.dart';
import 'widgets/cots_gradient_primary_button.dart';
import 'widgets/ocean_background.dart';
import 'auth_routes.dart';
import 'login_screen.dart';

/// Create Account screen — marine-themed signup with validation.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  /// Empty string means role not chosen yet (matches first dropdown item).
  String _role = '';
  String? _organization;

  static const _roles = <String>[
    'Field Monitor',
    'Researcher',
    'Marine Biologist',
    'Park Ranger',
    'Administrator',
  ];

  static const _organizations = <String>[
    'Great Barrier Reef Marine Park',
    'Local Reef Conservation NGO',
    'University Research Unit',
    'Government Fisheries',
    'Private contractor',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter your full name';
    if (s.length < 2) return 'Enter a valid name';
    return null;
  }

  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter your email';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    if (!ok) return 'Enter a valid email address';
    return null;
  }

  String? _validatePhone(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter your phone number';
    final digits = s.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) return 'Enter a valid phone number';
    return null;
  }

  String? _validateRole(String? v) {
    if (v == null || v.isEmpty) return 'Select your role';
    return null;
  }

  static List<DropdownMenuItem<String>> _roleItems() => [
        const DropdownMenuItem<String>(
          value: '',
          child: Text('Select your role', overflow: TextOverflow.ellipsis),
        ),
        ..._roles.map(
          (r) => DropdownMenuItem<String>(
            value: r,
            child: Text(r, overflow: TextOverflow.ellipsis),
          ),
        ),
      ];

  String? _validatePassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Create a password';
    if (s.length < 8) return 'Use at least 8 characters';
    return null;
  }

  String? _validateConfirm(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Confirm your password';
    if (s != _passwordCtrl.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    auth.clearLastError();

    try {
      await auth.signUp(
        fullName: _nameCtrl.text,
        email: _emailCtrl.text,
        phoneNumber: _phoneCtrl.text,
        positionRole: _role,
        organization: _organization,
        password: _passwordCtrl.text,
      );
      // Account exists but send user to login instead of staying signed in → dashboard.
      await auth.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      kRootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: kDarkTeal,
          content: Text('Account created. Sign in with your email and password.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = auth.lastError ?? AuthService.messageFor(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: kDangerRed,
          duration: const Duration(seconds: 6),
          content: Text(msg),
        ),
      );
    }
  }

  void _goLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: AppBackIconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          iconColor: kDarkTeal,
        ),
        title: const Text(
          'Create Account',
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
                            controller: _nameCtrl,
                            label: 'Full Name',
                            hint: 'Enter your full name',
                            prefixIcon: Icons.person_outline_rounded,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            validator: _validateName,
                          ),
                          const SizedBox(height: 18),
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
                          CotsAuthTextField(
                            controller: _phoneCtrl,
                            label: 'Phone Number',
                            hint: 'Enter your phone number',
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.telephoneNumber],
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[\d+\-\s().]')),
                            ],
                            validator: _validatePhone,
                          ),
                          const SizedBox(height: 18),
                          CotsAuthDropdown<String>(
                            label: 'Position / Role',
                            hint: 'Select your role',
                            prefixIcon: Icons.work_outline_rounded,
                            value: _role,
                            items: _roleItems(),
                            onChanged: (v) => setState(() => _role = v ?? ''),
                            validator: _validateRole,
                          ),
                          const SizedBox(height: 18),
                          CotsAuthDropdown<String?>(
                            label: 'Organization (Optional)',
                            hint: 'Select organization (optional)',
                            prefixIcon: Icons.business_outlined,
                            value: _organization,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('No organization', overflow: TextOverflow.ellipsis),
                              ),
                              ..._organizations.map(
                                (o) => DropdownMenuItem<String?>(
                                  value: o,
                                  child: Text(o, overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _organization = v),
                          ),
                          const SizedBox(height: 18),
                          CotsAuthPasswordField(
                            controller: _passwordCtrl,
                            label: 'Password',
                            hint: 'Create a password',
                            textInputAction: TextInputAction.next,
                            validator: _validatePassword,
                          ),
                          const SizedBox(height: 18),
                          CotsAuthPasswordField(
                            controller: _confirmCtrl,
                            label: 'Confirm Password',
                            hint: 'Confirm your password',
                            textInputAction: TextInputAction.done,
                            validator: _validateConfirm,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 26),
                          CotsGradientPrimaryButton(
                            label: 'Create Account',
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
                        'Already have an account? ',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: kMutedGray,
                            ),
                      ),
                      GestureDetector(
                        onTap: _goLogin,
                        child: Text(
                          'Login',
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
