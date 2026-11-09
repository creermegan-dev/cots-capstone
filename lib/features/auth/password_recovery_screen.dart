import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/cots_colors.dart';
import '../../services/auth_service.dart';
import '../../services/password_recovery_service.dart';
import '../../services/supabase_auth_service.dart';
import 'widgets/cots_auth_password_field.dart';
import 'widgets/cots_auth_text_field.dart';
import 'widgets/cots_gradient_primary_button.dart';

enum _RecoveryStep { email, code, password, done }

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen(
      {super.key, this.initialEmail = '', this.service});
  final String initialEmail;

  /// The screen owns this service, including disposal. Optional for tests.
  final PasswordRecoveryService? service;
  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late final PasswordRecoveryService _service;
  _RecoveryStep _step = _RecoveryStep.email;
  bool _busy = false;
  String? _error;
  int _resendSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail.trim());
    _service = widget.service ?? PasswordRecoveryService();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    unawaited(_service.dispose());
    super.dispose();
  }

  void _setStep(_RecoveryStep step) {
    _step = step;
    _form = GlobalKey<FormState>();
  }

  void _cooldown() {
    _timer?.cancel();
    _resendSeconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) timer.cancel();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is StateError
            ? error.message.toString()
            : AuthService.messageFor(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    if (_busy || (_step == _RecoveryStep.code && _resendSeconds > 0)) return;
    if (_step == _RecoveryStep.email && !_form.currentState!.validate()) return;
    await _run(() async {
      await _service.sendCode(_email.text);
      if (!mounted) return;
      _code.clear();
      setState(() {
        _setStep(_RecoveryStep.code);
        _cooldown();
      });
    });
  }

  Future<void> _verify() async {
    if (_busy || !_form.currentState!.validate()) return;
    await _run(() async {
      await _service.verifyCode(_email.text, _code.text);
      if (!mounted) return;
      _code.clear();
      setState(() => _setStep(_RecoveryStep.password));
    });
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    await _run(() async {
      await _service.setNewPassword(_password.text);
      if (!mounted) return;
      _password.clear();
      _confirmation.clear();
      _timer?.cancel();
      setState(() => _setStep(_RecoveryStep.done));
    });
  }

  void _startAgain() {
    _code.clear();
    _password.clear();
    _confirmation.clear();
    setState(() {
      _setStep(_RecoveryStep.email);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _RecoveryStep.email => 'Forgot password',
      _RecoveryStep.code => 'Check your email',
      _RecoveryStep.password => 'Choose a new password',
      _RecoveryStep.done => 'Password changed',
    };
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          backgroundColor: const Color(0xFFF5FBFC),
          appBar: AppBar(title: const Text('Reset password')),
          body: SafeArea(
              child: Center(
                  child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.lock_reset,
                          size: 48, color: kPrimaryTeal),
                      const SizedBox(height: 16),
                      Text(title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: kDarkTeal)),
                      const SizedBox(height: 16),
                      if (_step == _RecoveryStep.email) ...[
                        const Text(
                            'Enter the email address for your COTS Monitor account.'),
                        const SizedBox(height: 16),
                        AbsorbPointer(
                            absorbing: _busy,
                            child: CotsAuthTextField(
                              controller: _email,
                              label: 'Email address',
                              hint: 'you@example.com',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.send,
                              onFieldSubmitted: (_) => _sendCode(),
                              validator: (value) =>
                                  RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                          .hasMatch((value ?? '').trim())
                                      ? null
                                      : 'Enter a valid email address.',
                            )),
                      ],
                      if (_step == _RecoveryStep.code) ...[
                        Text(
                            'If an account exists for ${_email.text.trim()}, a recovery code has been sent. Check your inbox and Spam folder, then enter the newest code.'),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _code,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10)
                          ],
                          decoration: const InputDecoration(
                              labelText: 'Recovery code',
                              border: OutlineInputBorder()),
                          validator: (value) =>
                              SupabaseAuthService.isValidCode(value ?? '')
                                  ? null
                                  : 'Enter the code from your email.',
                          onFieldSubmitted: (_) => _verify(),
                        ),
                        TextButton(
                            onPressed:
                                _busy || _resendSeconds > 0 ? null : _sendCode,
                            child: Text(_resendSeconds > 0
                                ? 'Send new code in ${_resendSeconds}s'
                                : 'Send new code')),
                      ],
                      if (_step == _RecoveryStep.password) ...[
                        const Text(
                            'Use at least 12 characters. Your new password stays private.'),
                        const SizedBox(height: 16),
                        AbsorbPointer(
                            absorbing: _busy,
                            child: CotsAuthPasswordField(
                              controller: _password,
                              label: 'New password',
                              hint: 'At least 12 characters',
                              textInputAction: TextInputAction.next,
                              validator: (value) => (value ?? '').length >=
                                      PasswordRecoveryService
                                          .minimumPasswordLength
                                  ? null
                                  : 'Use at least 12 characters.',
                            )),
                        const SizedBox(height: 16),
                        AbsorbPointer(
                            absorbing: _busy,
                            child: CotsAuthPasswordField(
                              controller: _confirmation,
                              label: 'Confirm new password',
                              hint: 'Enter your new password again',
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _save(),
                              validator: (value) => value == _password.text
                                  ? null
                                  : 'Passwords do not match.',
                            )),
                      ],
                      if (_step == _RecoveryStep.done)
                        const Text(
                            'Your password has been updated. Return to login and sign in with your new password. Device verification still applies.'),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                            liveRegion: true,
                            child: Text(_error!,
                                style: const TextStyle(color: kDangerRed))),
                      ],
                      const SizedBox(height: 24),
                      if (_step != _RecoveryStep.done)
                        CotsGradientPrimaryButton(
                          label: switch (_step) {
                            _RecoveryStep.email => 'Send recovery code',
                            _RecoveryStep.code => 'Verify code',
                            _ => 'Save new password',
                          },
                          isLoading: _busy,
                          onPressed: () {
                            if (_busy) return;
                            switch (_step) {
                              case _RecoveryStep.email:
                                _sendCode();
                              case _RecoveryStep.code:
                                _verify();
                              case _RecoveryStep.password:
                                _save();
                              case _RecoveryStep.done:
                                break;
                            }
                          },
                        ),
                      if (_step == _RecoveryStep.code ||
                          _step == _RecoveryStep.password)
                        TextButton(
                            onPressed: _busy ? null : _startAgain,
                            child: const Text('Start again')),
                      TextButton(
                          onPressed:
                              _busy ? null : () => Navigator.of(context).pop(),
                          child: Text(_step == _RecoveryStep.done
                              ? 'Back to login'
                              : 'Cancel')),
                    ],
                  )),
            ),
          ))),
        ));
  }
}
