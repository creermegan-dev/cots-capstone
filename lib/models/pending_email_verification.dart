import 'package:flutter/foundation.dart';

/// Why the app is asking for an email code.
enum EmailVerificationReason {
  /// The account's email has never been verified (first sign-in).
  firstLogin,

  /// The password was correct, but this device is not trusted yet.
  newDevice,
}

@immutable
class PendingEmailVerification {
  const PendingEmailVerification({
    required this.email,
    required this.reason,
    this.codeSentAt,
  });

  final String email;
  final EmailVerificationReason reason;

  /// When this app last asked Supabase to email a code, if it did.
  final DateTime? codeSentAt;

  static const Duration resendCooldown = Duration(seconds: 60);

  PendingEmailVerification withCodeSentAt(DateTime value) =>
      PendingEmailVerification(email: email, reason: reason, codeSentAt: value);

  /// Seconds until another code may be requested (0 when allowed).
  int secondsUntilResend(DateTime now) {
    final sent = codeSentAt;
    if (sent == null) return 0;
    final remaining = resendCooldown - now.difference(sent);
    if (remaining <= Duration.zero) return 0;
    return (remaining.inMilliseconds / 1000).ceil();
  }
}
