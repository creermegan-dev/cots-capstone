import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/firebase_bootstrap.dart';
import '../core/supabase_config.dart';
import '../models/app_notification.dart';
import '../models/record_collection.dart';
import 'scan_record_repository.dart';
import 'windows_notification_rest_service.dart';

/// Stores and streams user-visible notifications from COTS workflows.
///
/// With the Supabase backend the database creates notifications itself
/// (see migration 20261030000300_capture_notifications.sql), so the app only
/// reads them, marks them read and dismisses them. The Firebase paths below
/// are kept unchanged for rollback.
abstract final class NotificationRepository {
  static final WindowsNotificationRestService _windows =
      WindowsNotificationRestService();

  static bool get _useSupabase => SupabaseConfig.isConfigured;

  static const supabaseColumns =
      'id,recipient_id,read_at,created_at,'
      'workflow_events(action,details,capture_id,request_id,created_at)';

  static const _supabaseRefresh = Duration(seconds: 15);

  static CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection(RecordCollection.notifications);

  /// Streams the signed-in person's notifications. With Supabase, [uid] is
  /// not needed (the database only returns the person's own rows); the
  /// special value 'experts' keeps only follow-up workflow notices.
  static Stream<List<AppNotification>> watchForUser(String uid) {
    if (_useSupabase) {
      return _watchSupabase(workflowOnly: uid == 'experts');
    }
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
    if (_useSupabase) {
      await Supabase.instance.client.rpc<dynamic>(
        'mark_notification_read',
        params: {'nid': notificationId},
      );
      return;
    }
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
    if (_useSupabase) {
      await Supabase.instance.client.rpc<dynamic>('mark_all_notifications_read');
      return;
    }
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
    if (_useSupabase) {
      // Notifications are kept as history; clearing hides them from the list.
      await Supabase.instance.client.rpc<dynamic>(
        'dismiss_notifications',
        params: {'ids': [for (final item in notifications) item.id]},
      );
      return;
    }
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
    // The Supabase database creates notifications itself.
    if (_useSupabase) return;
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

  static Stream<List<AppNotification>> _watchSupabase({
    required bool workflowOnly,
  }) async* {
    var first = true;
    while (true) {
      if (!first) await Future<void>.delayed(_supabaseRefresh);
      first = false;
      try {
        yield await _loadSupabase(workflowOnly: workflowOnly);
      } catch (error, stackTrace) {
        // Report the problem but keep refreshing, so a brief network drop
        // does not leave the list broken until the screen is reopened.
        yield* Stream<List<AppNotification>>.error(error, stackTrace);
      }
    }
  }

  static Future<List<AppNotification>> _loadSupabase({
    required bool workflowOnly,
  }) async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return <AppNotification>[];
    final rows = await client
        .from('notifications')
        .select(supabaseColumns)
        .isFilter('dismissed_at', null)
        .order('created_at', ascending: false)
        .limit(100);
    return fromSupabaseRows(rows, workflowOnly: workflowOnly);
  }

  /// Converts Supabase rows to notifications, newest first. With
  /// [workflowOnly], detection notices are left out.
  static List<AppNotification> fromSupabaseRows(
    List<dynamic> rows, {
    bool workflowOnly = false,
  }) {
    final notifications = <AppNotification>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      if (workflowOnly) {
        final event = row['workflow_events'];
        if (event is Map && event['capture_id'] != null) continue;
      }
      notifications.add(AppNotification.fromSupabase(row));
    }
    return _sorted(notifications);
  }

  static List<AppNotification> _sorted(List<AppNotification> notifications) {
    notifications.sort(
      (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return notifications;
  }
}
