import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firebase_bootstrap.dart';
import '../models/intervention_assignment_model.dart';
import '../models/record_collection.dart';
import 'scan_record_repository.dart';
import 'windows_intervention_assignment_rest_service.dart';

/// Persists and streams intervention assignments.
abstract final class InterventionAssignmentRepository {
  static final WindowsInterventionAssignmentRestService _windows =
      WindowsInterventionAssignmentRestService();

  static CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance
          .collection(RecordCollection.interventionAssignments);

  static Stream<List<InterventionAssignmentModel>> watchForAssignee(
    String uid,
  ) {
    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) {
        return Stream.error(
          StateError('Not signed in — cannot load assigned tasks.'),
        );
      }
      return _windows.watchForAssignee(idToken: token, uid: uid);
    }
    return _collection
        .where('assigned_to_uid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final items =
          snapshot.docs.map(InterventionAssignmentModel.fromFirestore).toList();
      items.sort(
        (a, b) =>
            (a.dueAt ?? DateTime(9999)).compareTo(b.dueAt ?? DateTime(9999)),
      );
      return items;
    });
  }

  static Stream<InterventionAssignmentModel?> watchForCapture(
    String captureId,
  ) {
    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) {
        return Stream.error(
          StateError('Not signed in — cannot load assignment.'),
        );
      }
      return Stream.periodic(const Duration(seconds: 15), (_) => null)
          .asyncMap(
            (_) => _windows.getByCapture(
              idToken: token,
              captureId: captureId,
            ),
          )
          .startWithFuture(
            _windows.getByCapture(idToken: token, captureId: captureId),
          );
    }
    return _collection.doc(captureId).snapshots().map(
          (doc) => doc.exists
              ? InterventionAssignmentModel.fromFirestore(doc)
              : null,
        );
  }

  static Future<InterventionAssignmentModel?> getForCapture(
    String captureId,
  ) async {
    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) return null;
      return _windows.getByCapture(
        idToken: token,
        captureId: captureId,
      );
    }
    await ensureFirebaseInitialized();
    final doc = await _collection.doc(captureId).get();
    return doc.exists ? InterventionAssignmentModel.fromFirestore(doc) : null;
  }

  static Future<void> assign(
    InterventionAssignmentModel assignment,
  ) async {
    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) {
        throw StateError('Not signed in — cannot assign personnel.');
      }
      await _windows.assign(idToken: token, assignment: assignment);
      return;
    }
    await ensureFirebaseInitialized();
    await _collection.doc(assignment.captureId).set({
      'capture_id': assignment.captureId,
      'capture_display_id': assignment.captureDisplayId,
      'zone': assignment.zone,
      'assigned_to_uid': assignment.assignedToUid,
      'assigned_to_name': assignment.assignedToName,
      'assigned_by_uid': assignment.assignedByUid,
      'assigned_by_name': assignment.assignedByName,
      'assigned_at': FieldValue.serverTimestamp(),
      'due_at': Timestamp.fromDate(
        assignment.dueAt ?? DateTime.now().add(const Duration(days: 7)),
      ),
      'status': InterventionAssignmentModel.assignedStatus,
      'removal_record_id': '',
    });
  }

  static Future<void> markEvidenceSubmitted({
    required String captureId,
    required String removalRecordId,
  }) async {
    await _updateStatus(
      captureId: captureId,
      status: InterventionAssignmentModel.evidenceSubmittedStatus,
      removalRecordId: removalRecordId,
      includeEvidenceTime: true,
    );
  }

  static Future<void> markCleared(String captureId) async {
    await _updateStatus(
      captureId: captureId,
      status: InterventionAssignmentModel.clearedStatus,
    );
  }

  static Future<void> _updateStatus({
    required String captureId,
    required String status,
    String removalRecordId = '',
    bool includeEvidenceTime = false,
  }) async {
    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) {
        throw StateError('Not signed in — cannot update assignment.');
      }
      await _windows.updateStatus(
        idToken: token,
        captureId: captureId,
        status: status,
        removalRecordId: removalRecordId,
      );
      return;
    }
    await ensureFirebaseInitialized();
    await _collection.doc(captureId).update({
      'status': status,
      'removal_record_id': removalRecordId,
      if (includeEvidenceTime)
        'evidence_submitted_at': FieldValue.serverTimestamp(),
    });
  }
}

extension _InitialFutureStream<T> on Stream<T> {
  Stream<T> startWithFuture(Future<T> first) async* {
    yield await first;
    yield* this;
  }
}
