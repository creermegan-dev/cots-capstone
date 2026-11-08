import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/user_model.dart';

/// Limited expert directory and personnel verification. Account access is unchanged.
abstract final class ExpertPersonnelRepository {
  static Future<void> setVerification(UserModel user, bool verified) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(
          'Expert personnel verification requires Supabase configuration.');
    }
    if (user.isAdmin || user.isExpert || !user.isActive) {
      throw StateError(
          'Only active field personnel can be verified or revoked.');
    }
    await Supabase.instance.client.rpc('verify_personnel', params: {
      'person': user.uid,
      'verified': verified,
      'enabled': user.isActive,
    });
  }

  static Future<List<UserModel>> fetchUsers() async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('The Expert directory requires Supabase configuration.');
    }
    final result =
        await Supabase.instance.client.rpc('expert_personnel_directory');
    return (result as List<dynamic>).map((value) {
      final row = Map<String, dynamic>.from(value as Map);
      return UserModel.fromSupabaseProfile(
        row,
        email: '',
        privilegedRole: row['account_role'] as String?,
      );
    }).toList();
  }
}
