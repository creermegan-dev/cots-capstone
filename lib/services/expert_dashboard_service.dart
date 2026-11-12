import 'package:supabase_flutter/supabase_flutter.dart';

/// A saved Expert decision, not an automatic AI acceptance.
class ExpertDashboardDecision {
  const ExpertDashboardDecision(
      {required this.id,
      required this.captureId,
      required this.decision,
      required this.at});
  final String id, captureId, decision;
  final DateTime? at;

  String get label => switch (decision) {
        'approve' => 'Approved',
        'reject' => 'Rejected',
        'correct' => 'Corrected',
        'historical_only' => 'Historical only',
        _ => 'Reviewed',
      };
}

/// Read-only dashboard history using existing tables and their existing RLS.
class ExpertDashboardApi {
  const ExpertDashboardApi({this.client});
  final SupabaseClient? client;

  Future<List<ExpertDashboardDecision>> recentDecisions() async {
    final rows = await (client ?? Supabase.instance.client)
        .from('expert_decisions')
        .select('id,capture_id,decision,decided_at')
        .not('capture_id', 'is', null)
        .order('decided_at', ascending: false)
        .limit(8);
    return [
      for (final row in rows)
        ExpertDashboardDecision(
          id: row['id'].toString(),
          captureId: row['capture_id'].toString(),
          decision: row['decision'].toString(),
          at: DateTime.tryParse(row['decided_at']?.toString() ?? ''),
        )
    ];
  }
}
