import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firebase_bootstrap.dart';
import '../models/capture_model.dart';
import '../models/removal_record_model.dart';
import '../models/record_collection.dart';
import 'capture_repository.dart';
import 'scan_record_repository.dart';
import 'windows_removal_record_rest_service.dart';

/// Reads removal activities from Firestore `removal_records`.
abstract final class RemovalRecordRepository {
  static final WindowsRemovalRecordRestService _windowsRest =
      WindowsRemovalRecordRestService();

  static CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection(RecordCollection.removalRecords);

  static Stream<List<RemovalRecordModel>> watchAll() {
    return watchAllWithCaptureLinks();
  }

  static Stream<List<RemovalRecordModel>> watchAllWithCaptureLinks() {
    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) {
        return Stream.error(
          StateError('Not signed in — cannot load removal records.'),
        );
      }
      return CaptureRepository.watchAll().asyncMap((captures) async {
        final links = _linksFromCaptures(captures);
        return _windowsRest.queryAll(
          idToken: token,
          captureLinks: links,
        );
      });
    }

    return _collection
        .orderBy('submitted_at', descending: true)
        .snapshots()
        .asyncMap((snap) async {
      final removals =
          snap.docs.map((d) => RemovalRecordModel.fromFirestore(d)).toList();
      return _attachCaptureLinks(removals);
    });
  }

  static Stream<List<RemovalRecordModel>> watchForUser(String uid) {
    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) {
        return Stream.error(
          StateError('Not signed in — cannot load removal records.'),
        );
      }
      return CaptureRepository.watchForUser(uid).asyncMap((captures) async {
        final links = _linksFromCaptures(captures);
        return _windowsRest.queryForUser(
          idToken: token,
          uid: uid,
          captureLinks: links,
        );
      });
    }

    return _collection.where('uid', isEqualTo: uid).snapshots().asyncMap((snap) {
      final removals =
          snap.docs.map((d) => RemovalRecordModel.fromFirestore(d)).toList();
      removals.sort(
        (a, b) => (b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return _attachCaptureLinks(removals);
    });
  }

  static Future<List<RemovalRecordModel>> _attachCaptureLinks(
    List<RemovalRecordModel> removals,
  ) async {
    if (removals.isEmpty) return removals;

    final captureIds =
        removals.map((r) => r.captureId).where((id) => id.isNotEmpty).toSet();
    final links = <String, CaptureLink>{};

    for (final id in captureIds) {
      final capture = await CaptureRepository.getById(id);
      if (capture != null) {
        links[id] = CaptureLink(
          id: capture.id,
          displayId: capture.displayRecordId,
          aiCount: capture.aiDetectedCount,
          zone: capture.zone,
        );
      }
    }

    return [
      for (final r in removals)
        RemovalRecordModel(
          id: r.id,
          captureId: r.captureId,
          uid: r.uid,
          submittedBy: r.submittedBy,
          imageName: r.imageName,
          removedQuantity: r.removedQuantity,
          removalMethod: r.removalMethod,
          zone: r.zone,
          notes: r.notes,
          submittedAt: r.submittedAt,
          dateTaken: r.dateTaken,
          latitude: r.latitude,
          longitude: r.longitude,
          aiVerifiedCount: r.aiVerifiedCount,
          aiConfidence: r.aiConfidence,
          linkedCaptureDisplayId:
              links[r.captureId]?.displayId ?? r.linkedCaptureDisplayId,
          linkedCaptureAiCount:
              links[r.captureId]?.aiCount ?? r.linkedCaptureAiCount,
          storedDisplayRecordId: r.storedDisplayRecordId,
        ),
    ];
  }

  static Map<String, CaptureLink> _linksFromCaptures(
    List<CaptureModel> captures,
  ) {
    return {
      for (final c in captures)
        c.id: CaptureLink(
          id: c.id,
          displayId: c.displayRecordId,
          aiCount: c.aiDetectedCount,
          zone: c.zone,
        ),
    };
  }
}
