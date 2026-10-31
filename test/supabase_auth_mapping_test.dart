import 'package:cots_monitor/models/user_model.dart';
import 'package:cots_monitor/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Supabase profile mapping', () {
    final row = <String, dynamic>{
      'id': '00000000-0000-4000-8000-000000000001',
      'full_name': 'Diver One',
      'phone': '+63 900 000 0000',
      'job_title': 'Volunteer Diver',
      'organization': 'Reef Unit',
      'active': true,
      'field_verified': true,
      'verified_by': '00000000-0000-4000-8000-000000000010',
      'verified_at': '2026-10-16T01:00:00Z',
      'created_at': '2026-10-16T00:00:00Z',
    };

    test('ordinary profile retains identity and verification fields', () {
      final user = UserModel.fromSupabaseProfile(
        row,
        email: 'diver@example.invalid',
      );
      expect(user.uid, row['id']);
      expect(user.email, 'diver@example.invalid');
      expect(user.accountRole, UserModel.defaultAccountRole);
      expect(user.isVerifiedFieldPersonnel, isTrue);
      expect(user.createdAt, DateTime.utc(2026, 10, 16));
    });

    test('privileged slots, not profile metadata, determine app role', () {
      final admin = UserModel.fromSupabaseProfile(
        row,
        email: 'admin@example.invalid',
        privilegedRole: 'administrator',
      );
      final expert = UserModel.fromSupabaseProfile(
        row,
        email: 'expert@example.invalid',
        privilegedRole: 'expert',
      );
      expect(admin.isAdmin, isTrue);
      expect(expert.isExpert, isTrue);
      expect(admin.isVerifiedFieldPersonnel, isFalse);
      expect(expert.isVerifiedFieldPersonnel, isFalse);
    });
  });

  group('Supabase authentication messages', () {
    test('invalid credentials do not reveal whether an account exists', () {
      const error = AuthException(
        'server detail',
        code: 'invalid_credentials',
      );
      expect(AuthService.messageFor(error), 'Incorrect email or password.');
    });

    test('authorization errors use a safe message', () {
      const error =
          PostgrestException(message: 'private detail', code: '42501');
      expect(
        AuthService.messageFor(error),
        'You are not authorized to perform this action.',
      );
    });

    test('unknown backend details are not shown to users', () {
      const authError = AuthException(
        'internal tenant secret',
        code: 'unexpected',
      );
      const databaseError = PostgrestException(
        message: 'relation private_table does not exist',
        code: '42P01',
      );

      expect(AuthService.messageFor(authError), isNot(contains('secret')));
      expect(
        AuthService.messageFor(databaseError),
        isNot(contains('private_table')),
      );
    });
  });
}
