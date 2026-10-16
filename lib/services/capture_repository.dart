import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firebase_bootstrap.dart';
import '../models/capture_model.dart';
import '../models/record_collection.dart';
import 'scan_record_repository.dart';
import 'windows_capture_rest_service.dart';

/// Reads processed detection captures from Firestore `captures`.
abstract final class CaptureRepository {
  static final WindowsCaptureRestService _windowsRest =
      WindowsCaptureRestService();

  static CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection(RecordCollection.captures);

  static Stream<List<CaptureModel>> watchAll() {
    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) {
        return Stream.error(
          StateError('Not signed in — cannot load captures.'),
        );
      }
      return _windowsRest.watchAll(idToken: token);
    }
    return _collection.snapshots().map(
      (snap) {
        final captures = snap.docs.map(CaptureModel.fromFirestore).toList();
        captures.sort((a, b) => (b.submittedAt ?? DateTime(1970))
            .compareTo(a.submittedAt ?? DateTime(1970)));
        return captures;
      },
    );
  }

  static Stream<List<CaptureModel>> watchForUser(String uid) {
    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) {
        return Stream.error(
          StateError('Not signed in — cannot load captures.'),
        );
      }
      return _windowsRest.watchForUser(idToken: token, uid: uid);
    }
    return _collection.where('uid', isEqualTo: uid).snapshots().map((snap) {
      final records = snap.docs.map(CaptureModel.fromFirestore).toList();
      records.sort(
        (a, b) => (b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return records;
    });
  }

  static Future<CaptureModel?> getById(String captureId) async {
    if (captureId.trim().isEmpty) return null;

    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) return null;
      final all = await _windowsRest.queryAll(idToken: token);
      for (final c in all) {
        if (c.id == captureId) return c;
      }
      return null;
    }

    await ensureFirebaseInitialized();
    final snap = await _collection.doc(captureId).get();
    if (!snap.exists) return null;
    return CaptureModel.fromFirestore(snap);
  }
}
