import 'dart:async';

import 'package:flutter/foundation.dart';

enum SupabaseConfirmationPhase { processing, confirmed, error }

@immutable
class SupabaseConfirmationNotice {
  const SupabaseConfirmationNotice({
    required this.id,
    required this.phase,
    required this.message,
  });

  final int id;
  final SupabaseConfirmationPhase phase;
  final String message;
}

/// Shared callback contract for Supabase email confirmation.
///
/// [capture] is used by `supabase_flutter` as its deep-link predicate. This
/// records safe UI state without retaining or logging the callback URI, whose
/// authorization code must be treated as a credential.
abstract final class SupabaseAuthCallback {
  static const String redirectUrl = 'cots-monitor://auth-callback/';
  static const String scheme = 'cots-monitor';
  static const String host = 'auth-callback';

  static final StreamController<SupabaseConfirmationNotice> _controller =
      StreamController<SupabaseConfirmationNotice>.broadcast(sync: true);
  static final Set<int> _seenCallbacks = <int>{};
  static int _nextId = 0;
  static SupabaseConfirmationNotice? _latest;

  static Stream<SupabaseConfirmationNotice> get notices => _controller.stream;
  static SupabaseConfirmationNotice? get latest => _latest;

  static bool capture(Uri uri) {
    if (!matches(uri)) return false;

    final parameters = <String, String>{...uri.queryParameters};
    if (uri.fragment.isNotEmpty) {
      try {
        parameters.addAll(Uri.splitQueryString(uri.fragment));
      } on FormatException {
        _publish(
          SupabaseConfirmationPhase.error,
          'This confirmation link is invalid. Request a new confirmation email.',
        );
        return true;
      }
    }

    final hasAuthPayload = parameters.containsKey('code') ||
        parameters.containsKey('access_token') ||
        parameters.containsKey('error') ||
        parameters.containsKey('error_code') ||
        parameters.containsKey('error_description');
    if (!hasAuthPayload) return false;

    // Deduplicate warm-start and activity-recreation delivery without storing
    // the sensitive callback value itself.
    if (!_seenCallbacks.add(uri.toString().hashCode)) return true;

    final errorCode = parameters['error_code'] ?? parameters['error'] ?? '';
    final description = parameters['error_description'] ?? '';
    if (errorCode.isNotEmpty || description.isNotEmpty) {
      final detail = '$errorCode $description'.toLowerCase();
      final message = detail.contains('expired') ||
              detail.contains('otp_expired')
          ? 'This confirmation link has expired. Request a new confirmation email.'
          : 'This confirmation link is invalid or has already been used. Request a new email if needed.';
      _publish(SupabaseConfirmationPhase.error, message);
      return true;
    }

    _publish(
      SupabaseConfirmationPhase.processing,
      'Confirming your email and completing your profile...',
    );
    return true;
  }

  static bool matches(Uri uri) =>
      uri.scheme.toLowerCase() == scheme &&
      uri.host.toLowerCase() == host &&
      (uri.path.isEmpty || uri.path == '/');

  static void markConfirmed() {
    if (_latest?.phase != SupabaseConfirmationPhase.processing) return;
    _publish(
      SupabaseConfirmationPhase.confirmed,
      'Email confirmed. Your field-personnel access still requires Administrator approval.',
    );
  }

  static void markFailure(String message) {
    if (_latest?.phase != SupabaseConfirmationPhase.processing) return;
    _publish(SupabaseConfirmationPhase.error, message);
  }

  static void clear() {
    _latest = null;
  }

  static void _publish(SupabaseConfirmationPhase phase, String message) {
    final notice = SupabaseConfirmationNotice(
      id: ++_nextId,
      phase: phase,
      message: message,
    );
    _latest = notice;
    _controller.add(notice);
  }

  @visibleForTesting
  static void resetForTesting() {
    _latest = null;
    _seenCallbacks.clear();
    _nextId = 0;
  }
}
