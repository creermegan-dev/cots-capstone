import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Firebase Storage paths for user media — profile uploads work on all platforms via [putData].
class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// `users/{uid}/profile/profile.jpg`
  Reference profileImageRef(String uid, {String filename = 'profile.jpg'}) {
    return _storage.ref().child('users').child(uid).child('profile').child(filename);
  }

  /// Upload raw image bytes (works on Android, iOS, and Web).
  Future<String> uploadProfileImageBytes({
    required String uid,
    required Uint8List bytes,
    String filename = 'profile.jpg',
    String contentType = 'image/jpeg',
  }) async {
    final ref = profileImageRef(uid, filename: filename);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  Future<void> deleteProfileImage(String uid, {String filename = 'profile.jpg'}) async {
    try {
      await profileImageRef(uid, filename: filename).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      rethrow;
    }
  }
}
