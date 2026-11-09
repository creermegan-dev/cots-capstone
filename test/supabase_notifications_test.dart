import 'package:cots_monitor/models/app_notification.dart';
import 'package:cots_monitor/services/notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row({
  required String id,
  required String action,
  String? createdAt,
  String? readAt,
  String? captureId = 'c1',
  Map<String, dynamic>? details,
}) => {
      'id': id,
      'recipient_id': 'u1',
      'read_at': readAt,
      'created_at': createdAt ?? '2026-10-30T08:00:00Z',
      'workflow_events': {
        'action': action,
        'capture_id': captureId,
        'created_at': createdAt ?? '2026-10-30T08:00:00Z',
        'details': details ??
            {
              'title': 'Scan submitted',
              'body': 'Your report CAP-ABCDEF12 was submitted.',
              'record_id': 'CAP-ABCDEF12',
              'zone': 'Samal Reef',
            },
      },
    };

void main() {
  test('reads wording, record label, zone and read state from Supabase', () {
    final n = AppNotification.fromSupabase(
      _row(id: 'n1', action: 'scan_submitted', readAt: '2026-10-30T09:00:00Z'),
    );
    expect(n.id, 'n1');
    expect(n.recipientUid, 'u1');
    expect(n.type, AppNotification.scanSubmitted);
    expect(n.title, 'Scan submitted');
    expect(n.body, contains('CAP-ABCDEF12'));
    expect(n.relatedRecordId, 'CAP-ABCDEF12');
    expect(n.zone, 'Samal Reef');
    expect(n.isRead, isTrue);
    expect(n.createdAt, DateTime.utc(2026, 10, 30, 8).toLocal());
  });

  test('unread when read_at is empty', () {
    final n = AppNotification.fromSupabase(_row(id: 'n1', action: 'x'));
    expect(n.isRead, isFalse);
  });

  test('events saved without a title still get a readable one', () {
    final n = AppNotification.fromSupabase(
      _row(id: 'n1', action: 'request_created', details: const {}),
    );
    expect(n.title, 'Request created');
    expect(n.body, '');
    expect(AppNotification.titleForType(''), 'Notification');
  });

  test('a missing event does not break the list', () {
    final n = AppNotification.fromSupabase({
      'id': 'n1',
      'recipient_id': 'u1',
      'read_at': null,
      'created_at': '2026-10-30T08:00:00Z',
      'workflow_events': null,
    });
    expect(n.title, 'Notification');
    expect(n.type, '');
  });

  test('rows are sorted newest first', () {
    final list = NotificationRepository.fromSupabaseRows([
      _row(id: 'old', action: 'scan_submitted', createdAt: '2026-10-29T08:00:00Z'),
      _row(id: 'new', action: 'review_accepted', createdAt: '2026-10-30T08:00:00Z'),
    ]);
    expect(list.map((n) => n.id), ['new', 'old']);
  });

  test('the follow-up list leaves out detection notices', () {
    final list = NotificationRepository.fromSupabaseRows([
      _row(id: 'detection', action: 'review_needed'),
      _row(id: 'workflow', action: 'request_created', captureId: null),
    ], workflowOnly: true);
    expect(list.map((n) => n.id), ['workflow']);
  });

  test('replacement notices open the replacement request', () {
    final n = AppNotification.fromSupabase({
      'id': 'n1',
      'recipient_id': 'u1',
      'read_at': null,
      'created_at': '2026-10-30T08:00:00Z',
      'workflow_events': {
        'action': 'replacement_proposed',
        'capture_id': null,
        'request_id': 'req-1',
        'details': {
          'title': 'New follow-up assignment',
          'body': 'October 2026 · Test Reef (C-01)',
          'record_id': 'req-1',
        },
      },
    });
    expect(n.type, AppNotification.followUpReassignment);
    expect(n.relatedRecordId, 'req-1');
    expect(n.title, 'New follow-up assignment');
  });

  test('the query asks only for what the list needs', () {
    expect(NotificationRepository.supabaseColumns,
        contains(
            'workflow_events(action,details,capture_id,request_id,created_at)'));
  });
}
