import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';

/// Local access to field work only, after this installation was trusted online.
/// Does not authenticate requests or grant server permissions.
class OfflineProfileStore {
  const OfflineProfileStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;
  static const _key = 'cots_monitor.offline_field_profile.v1';

  static bool isConnectionFailure(Object error) =>
      error is SocketException ||
      error is http.ClientException ||
      error is AuthRetryableFetchException ||
      error is TimeoutException;

  Future<void> save(UserModel profile, String deviceSecret) async {
    if (!profile.isActive || profile.isAdmin || profile.isExpert) {
      await clear();
      return;
    }
    final map = profile.toMap()
      ..remove('createdAt')
      ..remove('personnelVerifiedAt');
    map['createdAt'] = profile.createdAt?.toIso8601String();
    map['personnelVerifiedAt'] = profile.personnelVerifiedAt?.toIso8601String();
    await _storage.write(
        key: _key,
        value: jsonEncode({
          'profile': map,
          'device': sha256.convert(utf8.encode(deviceSecret)).toString(),
        }));
  }

  Future<UserModel?> restore(String uid, String deviceSecret) async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['device'] !=
          sha256.convert(utf8.encode(deviceSecret)).toString()) {
        return null;
      }
      final map = Map<String, dynamic>.from(data['profile'] as Map);
      if (map['uid'] != uid) return null;
      map['createdAt'] = DateTime.tryParse(map['createdAt']?.toString() ?? '');
      final profile = UserModel.fromMap(map, uid: uid);
      if (!profile.isActive || profile.isAdmin || profile.isExpert) return null;
      return profile;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() => _storage.delete(key: _key);
}
