import 'package:cots_monitor/models/capture_model.dart';
import 'package:cots_monitor/models/cots_confidence_policy.dart';
import 'package:cots_monitor/models/cots_detection_result.dart';
import 'package:cots_monitor/models/monitoring_analytics.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/models/staff_submission_rows.dart';
import 'package:cots_monitor/services/supabase_record_service.dart';
import 'package:flutter_test/flutter_test.dart';

CaptureModel photo({int threshold = 85, double score = .82}) => CaptureModel(
      id: 'policy-photo',
      uid: 'diver',
      submittedBy: 'Diver',
      imageName: 'photo.jpg',
      aiDetectedCount: 1,
      confidence: score,
      autoApproveMin: threshold,
      captureSource: 'GoPro Underwater Image',
      zone: 'Test site',
      notes: '',
      submittedAt: DateTime(2026, 11, 9),
      detectionBoxes: [
        CotsBoundingBox(x1: 1, y1: 1, x2: 10, y2: 10, score: score),
      ],
    );

void main() {
  test('new policy boundaries classify each detection individually', () {
    const expected = {
      0: CotsVerificationBand.retakeRequired,
      19: CotsVerificationBand.retakeRequired,
      20: CotsVerificationBand.adminReview,
      79: CotsVerificationBand.adminReview,
      80: CotsVerificationBand.adminReview,
      84: CotsVerificationBand.adminReview,
      85: CotsVerificationBand.aiAutoApproved,
      100: CotsVerificationBand.aiAutoApproved,
    };
    for (final entry in expected.entries) {
      expect(CotsConfidencePolicy.bandFromPercent(entry.key), entry.value,
          reason: '${entry.key}%');
    }
    // Preserve the app's existing rounded-percent policy at the new boundary.
    expect(CotsConfidencePolicy.bandFromConfidence(.8449),
        CotsVerificationBand.adminReview);
    expect(CotsConfidencePolicy.bandFromConfidence(.845),
        CotsVerificationBand.aiAutoApproved);
  });

  test('an 84 percent item still needs review beside a 100 percent item', () {
    final items = CotsConfidencePolicy.buildDetectionItems(
      count: 2,
      averagePercent: 92,
      boxes: const [
        CotsBoundingBox(x1: 1, y1: 1, x2: 10, y2: 10, score: .84),
        CotsBoundingBox(x1: 20, y1: 20, x2: 30, y2: 30, score: 1),
      ],
    );
    expect(CotsConfidencePolicy.recordBandFromItems(items),
        CotsVerificationBand.adminReview);
    expect(CotsConfidencePolicy.initialDecisionsForItems(items),
        [PerCotsAdminDecision.pending, PerCotsAdminDecision.confirmed]);
  });

  test('historical policy survives user and staff presentation adapters', () {
    final old = ScanRecordModel.fromCapture(photo(threshold: 80));
    final current = ScanRecordModel.fromCapture(photo());
    expect(old.cotsTally.confirmed, 1);
    expect(old.cotsTally.waiting, 0);
    expect(current.cotsTally.confirmed, 0);
    expect(current.cotsTally.waiting, 1);
    final row = old.toAdminTableRow(1);
    expect(row.autoApproveMin, 80);
    expect(row.copyWith().autoApproveMin, 80);
    expect(row.detectionReviewItems.single.band,
        CotsVerificationBand.aiAutoApproved);
    expect(StaffSubmissionRows.photo(row).autoApproveMin, 80);
    expect(
        CotsConfidencePolicy.userStatusDescriptionFromItems(
            old.detectionReviewItems),
        contains('80%–100%'));
    expect(
        CotsConfidencePolicy.userStatusDescription(85), contains('85%–100%'));
  });

  test('older Firebase records without policy metadata keep 80 percent', () {
    final old = CaptureModel.fromRestFields({
      'ai_detected_count': {'integerValue': '1'},
      'confidence': {'doubleValue': .82},
    }, id: 'old');
    final current = CaptureModel.fromRestFields({
      'auto_approve_min': {'integerValue': '85'},
    }, id: 'new');
    expect(old.autoApproveMin, 80);
    expect(current.autoApproveMin, 85);
    expect(ScanRecordModel.fromRestFields({}, id: 'legacy').autoApproveMin, 80);
  });

  test('review reconstruction uses the policy saved with the photo', () {
    for (final threshold in [80, 85]) {
      final state = SupabaseRecordService.reviewStateFor(
        status: 'finalized',
        itemIds: const ['item'],
        itemConfidences: const [.82],
        autoApproveMin: threshold,
        decisions: const [
          {'decision': 'approve', 'decision_sequence': 1, 'item_decisions': []},
        ],
      );
      expect(
          state.itemDecisions.single,
          threshold == 80
              ? PerCotsAdminDecision.confirmed
              : PerCotsAdminDecision.rejected);
    }
    final reviewed = SupabaseRecordService.reviewStateFor(
      status: 'finalized',
      itemIds: const ['item'],
      itemConfidences: const [.82],
      decisions: const [
        {
          'decision': 'approve',
          'decision_sequence': 1,
          'item_decisions': [
            {'item_id': 'item', 'decision': 'approve'},
          ]
        },
      ],
    );
    expect(reviewed.itemDecisions.single, PerCotsAdminDecision.confirmed);
  });

  test('analytics use current confidence ranges while preserving old totals',
      () {
    final analytics = MonitoringAnalytics.fromRecords([
      ScanRecordModel.fromCapture(photo(threshold: 80)),
    ]);
    expect(analytics.accepted, 1);
    expect(
        analytics.confidenceBands[CotsVerificationBand.adminReview.index], 1);
    expect(analytics.confidenceBands[CotsVerificationBand.aiAutoApproved.index],
        0);
  });
}
