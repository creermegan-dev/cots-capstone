import 'package:cots_monitor/core/supabase_auth_callback.dart';
import 'package:cots_monitor/services/auth_service.dart';
import 'package:cots_monitor/services/supabase_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(SupabaseAuthCallback.resetForTesting);

  group('Supabase confirmation callback', () {
    test('accepts the exact app callback and enters processing state', () {
      final accepted = SupabaseAuthCallback.capture(
        Uri.parse('cots-monitor://auth-callback/?code=one-time-code'),
      );

      expect(accepted, isTrue);
      expect(
        SupabaseAuthCallback.latest?.phase,
        SupabaseConfirmationPhase.processing,
      );
    });

    test('rejects unrelated or payload-free links', () {
      expect(
        SupabaseAuthCallback.capture(
          Uri.parse('other-app://auth-callback/?code=value'),
        ),
        isFalse,
      );
      expect(
        SupabaseAuthCallback.capture(
          Uri.parse('cots-monitor://wrong-host/?code=value'),
        ),
        isFalse,
      );
      expect(
        SupabaseAuthCallback.capture(
          Uri.parse('cots-monitor://auth-callback/'),
        ),
        isFalse,
      );
    });

    test('reports expired links without exposing callback details', () {
      SupabaseAuthCallback.capture(
        Uri.parse(
          'cots-monitor://auth-callback/?error=access_denied&'
          'error_code=otp_expired&error_description=secret-token-expired',
        ),
      );

      final notice = SupabaseAuthCallback.latest;
      expect(notice?.phase, SupabaseConfirmationPhase.error);
      expect(notice?.message, contains('expired'));
      expect(notice?.message, isNot(contains('secret-token')));
    });

    test('deduplicates repeated cold and warm callback delivery', () {
      final callback =
          Uri.parse('cots-monitor://auth-callback/?code=repeat-code');
      SupabaseAuthCallback.capture(callback);
      final firstId = SupabaseAuthCallback.latest?.id;

      SupabaseAuthCallback.capture(callback);

      expect(SupabaseAuthCallback.latest?.id, firstId);
    });

    test('confirmation keeps Administrator approval separate', () {
      SupabaseAuthCallback.capture(
        Uri.parse('cots-monitor://auth-callback/?code=value'),
      );
      SupabaseAuthCallback.markConfirmed();

      final notice = SupabaseAuthCallback.latest;
      expect(notice?.phase, SupabaseConfirmationPhase.confirmed);
      expect(notice?.message, contains('Administrator approval'));
    });
  });

  test('signup metadata includes editable details and no privileges', () {
    final metadata = SupabaseAuthService.signupMetadata(
      fullName: ' Diver One ',
      phoneNumber: ' +63 900 ',
      positionRole: ' Volunteer ',
      organization: ' Reef Unit ',
    );

    expect(metadata, <String, dynamic>{
      'full_name': 'Diver One',
      'phone': '+63 900',
      'job_title': 'Volunteer',
      'organization': 'Reef Unit',
    });
    expect(metadata, isNot(contains('account_role')));
    expect(metadata, isNot(contains('active')));
    expect(metadata, isNot(contains('field_verified')));
  });

  group('confirmation error messages', () {
    test('maps expired, invalid, rate-limit, and unconfirmed states', () {
      expect(
        AuthService.messageFor(
          const AuthException('private', code: 'otp_expired'),
        ),
        contains('expired'),
      );
      expect(
        AuthService.messageFor(
          const AuthException('private', code: 'bad_code_verifier'),
        ),
        contains('invalid'),
      );
      expect(
        AuthService.messageFor(
          const AuthException('private', code: 'over_email_send_rate_limit'),
        ),
        contains('Too many attempts'),
      );
      expect(
        AuthService.messageFor(
          const AuthException('private', code: 'email_not_confirmed'),
        ),
        contains('verify your email'),
      );
    });
  });
}
