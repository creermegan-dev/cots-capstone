import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/firebase_bootstrap.dart';
import '../core/supabase_config.dart';
import '../models/user_model.dart';
import 'scan_record_repository.dart';
import 'windows_personnel_rest_service.dart';

/// Live user directory and admin-controlled field-personnel eligibility.
abstract final class PersonnelRepository {
  static final WindowsPersonnelRestService _windows =
      WindowsPersonnelRestService();

  static CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');
  static SupabaseClient get _supabase => Supabase.instance.client;

  static Stream<List<UserModel>> watchUsers() {
    if (SupabaseConfig.isConfigured) {
      return Stream.fromFuture(_fetchSupabaseUsers());
    }
    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) {
        return Stream.error(
          StateError('Not signed in — cannot load personnel.'),
        );
      }
      return _windows.watchUsers(idToken: token);
    }
    return _users.snapshots().map((snapshot) {
      final users = snapshot.docs.map(UserModel.fromFirestore).toList();
      users.sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );
      return users;
    });
  }

  static Stream<List<UserModel>> watchVerifiedPersonnel() {
    return watchUsers().map(
      (users) => users.where((u) => u.isVerifiedFieldPersonnel).toList(),
    );
  }

  static Future<void> setVerification({
    required String userId,
    required bool verified,
    required String verifiedBy,
  }) async {
    if (SupabaseConfig.isConfigured) {
      await _supabase.rpc(
        'verify_personnel',
        params: <String, dynamic>{
          'person': userId,
          'verified': verified,
          'enabled': true,
        },
      );
      return;
    }
    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) {
        throw StateError('Not signed in — cannot verify personnel.');
      }
      await _windows.setPersonnelVerification(
        idToken: token,
        userId: userId,
        verified: verified,
        verifiedBy: verifiedBy,
      );
      return;
    }
    await ensureFirebaseInitialized();
    await _users.doc(userId).update({
      'fieldPersonnelVerified': verified,
      'personnelVerifiedBy': verified ? verifiedBy : '',
      'personnelVerifiedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<String> beginSupervisedRecovery({
    required String userId,
    required String verificationReference,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supervised recovery is available with Supabase Auth.');
    }
    final result = await _supabase.rpc(
      'begin_supervised_recovery',
      params: <String, dynamic>{
        'person': userId,
        'verification_ref': verificationReference.trim(),
      },
    );
    return result.toString();
  }

  static Future<List<UserModel>> _fetchSupabaseUsers() async {
    final result = await _supabase.rpc('administrator_personnel_directory');
    final rows = (result as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(
          (row) => UserModel.fromSupabaseProfile(
            row,
            email: row['email'] as String? ?? '',
            privilegedRole: row['account_role'] as String?,
          ),
        )
        .toList();
    rows.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return rows;
  }
}
