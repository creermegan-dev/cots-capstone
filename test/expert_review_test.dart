import 'package:cots_monitor/models/cots_confidence_policy.dart';
import 'package:cots_monitor/services/supabase_record_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ids = ['item-a', 'item-b', 'item-c'];

  group('decision sent to Supabase', () {
    test('maps each on-screen decision to its stored detection item', () {
      final results = SupabaseRecordService.buildExpertItemResults(
        itemIds: ids,
        decisions: const [
          PerCotsAdminDecision.confirmed,
          PerCotsAdminDecision.confirmed,
          PerCotsAdminDecision.rejected,
        ],
      );
      expect(results, [
        {'item_id': 'item-a', 'decision': 'approve'},
        {'item_id': 'item-b', 'decision': 'approve'},
        {'item_id': 'item-c', 'decision': 'reject'},
      ]);
    });

    test('pending items are left for the server to check', () {
      final results = SupabaseRecordService.buildExpertItemResults(
        itemIds: ids,
        decisions: const [
          PerCotsAdminDecision.confirmed,
          PerCotsAdminDecision.pending,
          PerCotsAdminDecision.rejected,
        ],
      );
      expect(results.map((r) => r['item_id']), ['item-a', 'item-c']);
    });

    test('a record that changed since it was opened is not reviewed', () {
      expect(
        () => SupabaseRecordService.buildExpertItemResults(
          itemIds: ids,
          decisions: const [PerCotsAdminDecision.confirmed],
        ),
        throwsStateError,
      );
    });

    test('a reason is always sent and kept within the database limit', () {
      expect(
        SupabaseRecordService.expertReason('  ', approve: true),
        'Approved after per-COTS review.',
      );
      expect(
        SupabaseRecordService.expertReason('', approve: false),
        'Rejected after review.',
      );
      expect(
        SupabaseRecordService.expertReason(' Clear photo ', approve: true),
        'Clear photo',
      );
      expect(
        SupabaseRecordService.expertReason('x' * 2500, approve: true).length,
        2000,
      );
    });
  });

  group('review state shown after loading', () {
    test('without a decision, the server status is shown', () {
      final state = SupabaseRecordService.reviewStateFor(
        status: 'finalized',
        itemIds: ids,
        itemConfidences: const [0.9, 0.9, 0.9],
        decisions: const [],
      );
      expect(state.confirmed, isTrue);
      expect(state.rejected, isFalse);
      expect(state.itemDecisions, isEmpty);
    });

    test('a pending record with no decision still needs review', () {
      final state = SupabaseRecordService.reviewStateFor(
        status: 'pending',
        itemIds: ids,
        itemConfidences: const [0.9, 0.5, 0.1],
        decisions: const [],
      );
      expect(state.confirmed, isFalse);
      expect(state.rejected, isFalse);
    });

    test('the latest Expert decision is shown before finalization', () {
      final state = SupabaseRecordService.reviewStateFor(
        status: 'pending',
        itemIds: ids,
        itemConfidences: const [0.92, 0.55, 0.12],
        decisions: const [
          {
            'decision': 'reject',
            'decision_sequence': 1,
            'item_decisions': <Object>[],
            'expert_id': 'expert-1',
            'decided_at': '2026-10-30T09:00:00Z',
          },
          {
            'decision': 'approve',
            'decision_sequence': 2,
            'item_decisions': [
              {'item_id': 'item-b', 'decision': 'approve'},
              {'item_id': 'item-c', 'decision': 'reject'},
            ],
            'expert_id': 'expert-1',
            'decided_at': '2026-10-30T10:00:00Z',
          },
        ],
      );
      expect(state.confirmed, isTrue);
      expect(state.rejected, isFalse);
      expect(state.itemDecisions, const [
        PerCotsAdminDecision.confirmed, // 92% auto-accepted
        PerCotsAdminDecision.confirmed, // approved by the Expert
        PerCotsAdminDecision.rejected, // rejected by the Expert
      ]);
      expect(state.reviewerId, 'expert-1');
      expect(state.reviewedAt, DateTime.utc(2026, 10, 30, 10));
    });

    test('a rejected record shows every COTS as rejected', () {
      final state = SupabaseRecordService.reviewStateFor(
        status: 'pending',
        itemIds: ids,
        itemConfidences: const [0.92, 0.55, 0.12],
        decisions: const [
          {
            'decision': 'reject',
            'decision_sequence': 3,
            'item_decisions': <Object>[],
            'expert_id': 'expert-1',
          },
        ],
      );
      expect(state.rejected, isTrue);
      expect(state.confirmed, isFalse);
      expect(
        state.itemDecisions,
        everyElement(PerCotsAdminDecision.rejected),
      );
    });
  });
}
