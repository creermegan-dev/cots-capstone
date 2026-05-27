import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

/// Firestore access for the `users` collection (document ID = Firebase UID).
class FirestoreUserService {
  FirestoreUserService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String usersCollection = 'users';

  DocumentReference<Map<String, dynamic>> userRef(String uid) =>
      _db.collection(usersCollection).doc(uid);

  Future<UserModel?> getUser(String uid) async {
    final snap = await userRef(uid).get();
    if (!snap.exists) return null;
    return UserModel.fromFirestore(snap);
  }

  Stream<UserModel?> watchUser(String uid) {
    return userRef(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserModel.fromFirestore(snap);
    });
  }

  /// Creates `users/{uid}` after Firebase Auth registration.
  Future<void> createUserProfile(UserModel model) async {
    await userRef(model.uid).set(model.toFirestoreCreateMap());
  }

  Future<void> updateProfileImage(String uid, String downloadUrl) async {
    await userRef(uid).update({
      'profileImage': downloadUrl,
    });
  }
}
