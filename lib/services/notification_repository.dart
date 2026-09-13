import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../core/firebase_bootstrap.dart';
import '../models/app_notification.dart';
import '../models/record_collection.dart';
import 'scan_record_repository.dart';
import 'windows_notification_rest_service.dart';

/// Stores and streams user-visible notifications from COTS workflows.
abstract final class NotificationRepository {
  static final WindowsNotificationRestService _windows =
      WindowsNotificationRestService();

  static CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection(RecordCollection.notifications);

  static Stream<List<AppNotification>> watchForUser(String uid) {
    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) {
        return Stream.error(
          StateError('Not signed in — cannot load notifications.'),
        );
      }
      return _windows.watchForUser(idToken: token, uid: uid).map(_sorted);
    }
    return _collection.where('recipient_uid', isEqualTo: uid).snapshots().map(
      (snapshot) => _sorted(
        snapshot.docs.map(AppNotification.fromFirestore).toList(),
      ),
    );
  }

  static Future<void> createScanSubmitted({
    required String recipientUid,
    required String recordId,
    required int detectedCount,
    required String zone,
  }) => _create(
        recipientUid: recipientUid,
        type: AppNotification.scanSubmitted,
        title: 'Scan submitted',
        body: 'Your report $recordId was submitted with $detectedCount COTS detected${zone == 'Unassigned' ? '.' : ' in $zone.'}',
        relatedRecordId: recordId,
        zone: zone,
      );

  static Future<void> createReviewDecision({
    required String recipientUid,
    required String recordId,
    required String zone,
    required bool accepted,
  }) => _create(
        recipientUid: recipientUid,
        type: accepted
            ? AppNotification.reviewAccepted
            : AppNotification.reviewRejected,
        title: accepted ? 'Report accepted' : 'Report rejected',
        body: accepted
            ? 'Your report $recordId${zone.isEmpty ? '' : ' for $zone'} has been accepted by an expert.'
            : 'Your report $recordId${zone.isEmpty ? '' : ' for $zone'} was rejected. Please review the record details.',
        relatedRecordId: recordId,
        zone: zone,
      );

  static Future<void> createInterventionAssigned({
    required String recipientUid,
    required String recordId,
    required String zone,
    required DateTime dueAt,
  }) => _create(
        recipientUid: recipientUid,
        type: AppNotification.interventionAssigned,
        title: 'Intervention task assigned',
        body: 'You have been assigned a COTS removal task${zone.isEmpty ? '' : ' in $zone'}. Due ${DateFormat('MMM d, yyyy').format(dueAt)}.',
        relatedRecordId: recordId,
        zone: zone,
        dueAt: dueAt,
      );

  static Future<void> markRead(String notificationId) async {
    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) throw StateError('Not signed in — cannot update notification.');
      return _windows.markRead(idToken: token, notificationId: notificationId);
    }
    await _collection.doc(notificationId).update({'is_read': true});
  }

  static Future<void> markAllRead(List<AppNotification> notifications) async {
    final unread = notifications.where((item) => !item.isRead).toList();
    if (unread.isEmpty) return;
    if (deferFirebaseUntilFirstUse) {
      for (final item in unread) {
        await markRead(item.id);
      }
      return;
    }
    final batch = FirebaseFirestore.instance.batch();
    for (final item in unread) {
      batch.update(_collection.doc(item.id), {'is_read': true});
    }
    await batch.commit();
  }

  static Future<void> clearAll(List<AppNotification> notifications) async {
    if (notifications.isEmpty) return;
    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) throw StateError('Not signed in — cannot clear notifications.');
      for (final item in notifications) {
        await _windows.delete(idToken: token, notificationId: item.id);
      }
      return;
    }
    final batch = FirebaseFirestore.instance.batch();
    for (final item in notifications) {
      batch.delete(_collection.doc(item.id));
    }
    await batch.commit();
  }

  static Future<void> _create({
    required String recipientUid,
    required String type,
    required String title,
    required String body,
    required String relatedRecordId,
    required String zone,
    DateTime? dueAt,
  }) async {
    if (recipientUid.isEmpty) return;
    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) throw StateError('Not signed in — cannot create notification.');
      return _windows.create(
        idToken: token,
        recipientUid: recipientUid,
        type: type,
        title: title,
        body: body,
        relatedRecordId: relatedRecordId,
        zone: zone,
        dueAt: dueAt,
      );
    }
    await ensureFirebaseInitialized();
    await _collection.add({
      'recipient_uid': recipientUid,
      'type': type,
      'title': title,
      'body': body,
      'related_record_id': relatedRecordId,
      'zone': zone,
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
      if (dueAt != null) 'due_at': Timestamp.fromDate(dueAt),
    });
  }

  static List<AppNotification> _sorted(List<AppNotification> notifications) {
    notifications.sort(
      (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return notifications;
  }
}
