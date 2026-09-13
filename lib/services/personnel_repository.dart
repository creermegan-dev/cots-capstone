import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firebase_bootstrap.dart';
import '../models/user_model.dart';
import 'scan_record_repository.dart';
import 'windows_personnel_rest_service.dart';

/// Live user directory and admin-controlled field-personnel eligibility.
abstract final class PersonnelRepository {
  static final WindowsPersonnelRestService _windows =
      WindowsPersonnelRestService();

  static CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  static Stream<List<UserModel>> watchUsers() {
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
}
