import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/user_model.dart';

/// Read-only, limited directory. Never uses the administrator's private RPC.
abstract final class ExpertPersonnelRepository {
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
