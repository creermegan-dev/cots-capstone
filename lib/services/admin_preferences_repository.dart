import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/firebase_bootstrap.dart';
import '../core/supabase_config.dart';
import '../models/admin_preferences.dart';
import 'scan_record_repository.dart';
import 'windows_admin_preferences_rest_service.dart';

abstract interface class AdminPreferencesStore {
  Future<AdminPreferences> load(String uid);
  Future<void> save(AdminPreferences preferences);
}

class AdminPreferencesRepository implements AdminPreferencesStore {
  AdminPreferencesRepository({
    FirebaseFirestore? firestore,
    WindowsAdminPreferencesRestService? windowsService,
    SupabaseClient? supabaseClient,
  })  : _firestore = firestore,
        _supabaseClient = supabaseClient,
        _windowsService =
            windowsService ?? WindowsAdminPreferencesRestService();

  final FirebaseFirestore? _firestore;
  final SupabaseClient? _supabaseClient;
  bool get _useSupabase =>
      _supabaseClient != null || SupabaseConfig.isConfigured;
  SupabaseClient get _supabase => _supabaseClient ?? Supabase.instance.client;
  final WindowsAdminPreferencesRestService _windowsService;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  @override
  Future<AdminPreferences> load(String uid) async {
    if (_useSupabase) {
      final row = await _supabase
          .from('admin_preferences')
          .select()
          .eq('uid', uid)
          .maybeSingle();
      return row == null
          ? AdminPreferences.defaults(uid)
          : AdminPreferences.fromMap(uid, row);
    }
    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) throw StateError('Not signed in.');
      return _windowsService.load(uid: uid, idToken: token);
    }
    await ensureFirebaseInitialized();
    final snapshot = await _db.collection('admin_preferences').doc(uid).get();
    if (!snapshot.exists) return AdminPreferences.defaults(uid);
    return AdminPreferences.fromMap(uid, snapshot.data() ?? const {});
  }

  @override
  Future<void> save(AdminPreferences preferences) async {
    if (_useSupabase) {
      await _supabase
          .from('admin_preferences')
          .upsert(preferences.toMap(), onConflict: 'uid');
      return;
    }
    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) throw StateError('Not signed in.');
      await _windowsService.save(
        preferences: preferences,
        idToken: token,
      );
      return;
    }
    await ensureFirebaseInitialized();
    await _db
        .collection('admin_preferences')
        .doc(preferences.uid)
        .set(preferences.toMap());
  }
}
