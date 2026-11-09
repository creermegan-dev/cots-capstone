import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Optional profile photo stored in the private `profile-photos` bucket.
///
/// Files live at `<user id>/<random id>.jpg`. The database only lets a person
/// write inside their own folder; Experts and Administrators may view.
class ProfilePhotoService {
  ProfilePhotoService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const bucket = 'profile-photos';
  static const maxBytes = 1048576;
  static const _maxSide = 512;

  final SupabaseClient _client;

  static final Map<String, ({String url, DateTime expires})> _urlCache = {};

  /// Shrinks any picked image to a small JPEG (max 512 px, under 1 MB).
  static Uint8List shrinkToJpeg(Uint8List input) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(input);
    } catch (_) {
      decoded = null;
    }
    if (decoded == null) {
      throw const FormatException('This file is not a picture.');
    }
    var working = img.bakeOrientation(decoded);
    if (working.width > _maxSide || working.height > _maxSide) {
      working = working.width >= working.height
          ? img.copyResize(working, width: _maxSide)
          : img.copyResize(working, height: _maxSide);
    }
    for (final quality in const [85, 70, 55]) {
      final jpg = Uint8List.fromList(img.encodeJpg(working, quality: quality));
      if (jpg.length <= maxBytes) return jpg;
    }
    throw const FormatException('The picture is too large.');
  }

  static String newPath(String uid) {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    final id = '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
    return '$uid/$id.jpg';
  }

  /// Uploads a new photo, points the profile at it, then removes the old file.
  Future<String> upload(Uint8List pickedBytes, {String? oldPath}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AuthException('No signed-in user.');
    final jpg = await compute(shrinkToJpeg, pickedBytes);
    final path = newPath(uid);
    await _client.storage.from(bucket).uploadBinary(
          path,
          jpg,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: false),
        );
    await _client
        .from('profiles')
        .update(<String, dynamic>{'avatar_path': path}).eq('id', uid);
    await _removeFile(oldPath);
    return path;
  }

  /// Clears the profile photo and removes the file.
  Future<void> remove(String? oldPath) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AuthException('No signed-in user.');
    await _client
        .from('profiles')
        .update(<String, dynamic>{'avatar_path': null}).eq('id', uid);
    await _removeFile(oldPath);
  }

  Future<void> _removeFile(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    _urlCache.remove(path);
    try {
      await _client.storage.from(bucket).remove([path]);
    } catch (_) {
      // The profile no longer points at it; a leftover file is harmless.
    }
  }

  /// Short-lived private link for showing the photo.
  Future<String?> viewUrl(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    final cached = _urlCache[path];
    if (cached != null && cached.expires.isAfter(DateTime.now())) {
      return cached.url;
    }
    final url =
        await _client.storage.from(bucket).createSignedUrl(path, 60 * 60);
    _urlCache[path] = (
      url: url,
      expires: DateTime.now().add(const Duration(minutes: 50)),
    );
    return url;
  }
}
