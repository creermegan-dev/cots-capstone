/// Shared confidence thresholds and verification messaging for COTS detections.
import 'dart:math' as math;

import 'cots_detection_result.dart';

/// Per-COTS confidence policy (each labeled detection is evaluated individually):
/// - **80–100%** — Automatically Accepted.
/// - **20–79%** — Requires Expert Validation (accept/reject that specific COTS).
/// - **0–19%** — Too low; flagged for retake (auto-rejected per box).
///
/// Submission status is derived from all per-COTS scores — not the average alone.
abstract final class CotsConfidencePolicy {
  static const int autoApproveMin = 80;
  static const int adminReviewMin = 20;

  static int percentFromConfidence(double confidence) =>
      (confidence.clamp(0.0, 1.0) * 100).round();

  static CotsVerificationBand bandFromPercent(int percent) {
    if (percent >= autoApproveMin) return CotsVerificationBand.aiAutoApproved;
    if (percent >= adminReviewMin) return CotsVerificationBand.adminReview;
    return CotsVerificationBand.retakeRequired;
  }

  static CotsVerificationBand bandFromConfidence(double confidence) =>
      bandFromPercent(percentFromConfidence(confidence));

  /// Internal admin table status key.
  static String adminStatusKey({
    required int confidencePercent,
    bool adminConfirmed = false,
    bool adminRejected = false,
  }) {
    if (adminConfirmed) return 'Verified';
    if (adminRejected) return 'Rejected';
    return switch (bandFromPercent(confidencePercent)) {
      CotsVerificationBand.aiAutoApproved => 'Verified',
      CotsVerificationBand.adminReview => 'Needs Review',
      CotsVerificationBand.retakeRequired => 'Rejected',
    };
  }

  static String userStatusLabel(int confidencePercent) {
    return switch (adminStatusKey(confidencePercent: confidencePercent)) {
      'Verified' => 'Automatically Accepted',
      'Needs Review' => 'Requires Expert Validation',
      _ => 'Retake Photo',
    };
  }

  static String userStatusDescription(int confidencePercent) {
    return switch (bandFromPercent(confidencePercent)) {
      CotsVerificationBand.aiAutoApproved =>
        'The AI detection confidence is $confidencePercent%. This detection has been Automatically Accepted (80%–100% threshold).',
      CotsVerificationBand.adminReview =>
        'The AI detection confidence is $confidencePercent%, which is below the automatic acceptance threshold. This record has been forwarded to the Expert for manual verification before it becomes an official monitoring record.',
      CotsVerificationBand.retakeRequired =>
        'Confidence is below $adminReviewMin%. Please retake your GoPro photo — the image quality or detection clarity is too low.',
    };
  }

  static String adminStatusDescription({
    required int confidencePercent,
    bool adminConfirmed = false,
    bool adminRejected = false,
  }) {
    if (adminConfirmed) {
      return 'Expert completed per-COTS verification and accepted this submission.';
    }
    if (adminRejected) {
      return 'Expert completed per-COTS verification and rejected this submission.';
    }
    return switch (bandFromPercent(confidencePercent)) {
      CotsVerificationBand.aiAutoApproved =>
        'AI auto-approved at ${autoApproveMin}–100% confidence. Automatically Accepted.',
      CotsVerificationBand.adminReview =>
        'Confidence below ${autoApproveMin}% — Requires Expert Validation. Expert must accept or reject each labeled COTS below.',
      CotsVerificationBand.retakeRequired =>
        'Confidence 0–${adminReviewMin - 1}% — submission rejected. User should retake the photo.',
    };
  }

  static String acceptedStatSubtitle(int percent) =>
      '$percent% · Automatically Accepted ${autoApproveMin}–100%';

  static String reviewStatSubtitle(int percent) =>
      '$percent% · Requires Expert Validation ${adminReviewMin}–${autoApproveMin - 1}%';

  static String rejectedStatSubtitle(int percent) =>
      '$percent% · Retake photo 0–${adminReviewMin - 1}%';

  /// Whether this individual COTS needs expert accept/reject (20–79% band).
  static bool cotsNeedsAdminReview(int percent) =>
      bandFromPercent(percent) == CotsVerificationBand.adminReview;

  /// Initial decision for one COTS based on its own confidence score.
  static PerCotsAdminDecision initialDecisionForPercent(int percent) =>
      switch (bandFromPercent(percent)) {
        CotsVerificationBand.aiAutoApproved => PerCotsAdminDecision.confirmed,
        CotsVerificationBand.adminReview => PerCotsAdminDecision.pending,
        CotsVerificationBand.retakeRequired => PerCotsAdminDecision.rejected,
      };

  static List<PerCotsAdminDecision> initialDecisionsForItems(
    List<CotsDetectionReviewItem> items,
  ) =>
      items.map((i) => initialDecisionForPercent(i.confidencePercent)).toList();

  static int countAutoApproved(List<CotsDetectionReviewItem> items) =>
      items.where((i) => i.band == CotsVerificationBand.aiAutoApproved).length;

  static int countNeedingAdminReview(List<CotsDetectionReviewItem> items) =>
      items.where((i) => cotsNeedsAdminReview(i.confidencePercent)).length;

  static int countRetakeRequired(List<CotsDetectionReviewItem> items) =>
      items.where((i) => i.band == CotsVerificationBand.retakeRequired).length;

  /// True when any individual COTS is in the 20–79% band and awaits expert review.
  static bool submissionNeedsPerCotsReview(List<CotsDetectionReviewItem> items) =>
      items.any((i) => cotsNeedsAdminReview(i.confidencePercent));

  /// Record-level band from per-COTS scores (falls back to average when no items).
  static CotsVerificationBand recordBandFromItems(List<CotsDetectionReviewItem> items) {
    if (items.isEmpty) return CotsVerificationBand.retakeRequired;
    if (items.every((i) => i.band == CotsVerificationBand.aiAutoApproved)) {
      return CotsVerificationBand.aiAutoApproved;
    }
    if (items.every((i) => i.band == CotsVerificationBand.retakeRequired)) {
      return CotsVerificationBand.retakeRequired;
    }
    return CotsVerificationBand.adminReview;
  }

  static String adminStatusKeyFromItems({
    required List<CotsDetectionReviewItem> items,
    bool adminConfirmed = false,
    bool adminRejected = false,
  }) {
    if (adminConfirmed) return 'Verified';
    if (adminRejected) return 'Rejected';
    return switch (recordBandFromItems(items)) {
      CotsVerificationBand.aiAutoApproved => 'Verified',
      CotsVerificationBand.adminReview => 'Needs Review',
      CotsVerificationBand.retakeRequired => 'Rejected',
    };
  }

  static String userStatusLabelFromItems(
    List<CotsDetectionReviewItem> items, {
    bool adminConfirmed = false,
    bool adminRejected = false,
  }) {
    return switch (adminStatusKeyFromItems(
      items: items,
      adminConfirmed: adminConfirmed,
      adminRejected: adminRejected,
    )) {
      'Verified' => 'Automatically Accepted',
      'Needs Review' => 'Requires Expert Validation',
      _ => 'Retake Photo',
    };
  }

  static String userStatusDescriptionFromItems(
    List<CotsDetectionReviewItem> items, {
    bool adminConfirmed = false,
    bool adminRejected = false,
  }) {
    if (adminConfirmed) {
      return 'Expert completed per-COTS verification and accepted this submission.';
    }
    if (adminRejected) {
      return 'Expert completed per-COTS verification and rejected this submission.';
    }
    return switch (recordBandFromItems(items)) {
      CotsVerificationBand.aiAutoApproved => () {
          final avg = items.isEmpty
              ? autoApproveMin
              : (items.map((i) => i.confidencePercent).reduce((a, b) => a + b) /
                      items.length)
                  .round();
          return 'The AI detection confidence is $avg%. This detection has been Automatically Accepted (80%–100% threshold).';
        }(),
      CotsVerificationBand.adminReview => () {
          final avg = items.isEmpty
              ? adminReviewMin
              : (items.map((i) => i.confidencePercent).reduce((a, b) => a + b) /
                      items.length)
                  .round();
          return 'The AI detection confidence is $avg%, which is below the automatic acceptance threshold. This record has been forwarded to the Expert for manual verification before it becomes an official monitoring record.';
        }(),
      CotsVerificationBand.retakeRequired =>
        'All detections are below $adminReviewMin% confidence. Please retake your GoPro photo.',
    };
  }

  static String adminStatusDescriptionFromItems({
    required List<CotsDetectionReviewItem> items,
    bool adminConfirmed = false,
    bool adminRejected = false,
  }) {
    if (adminConfirmed) {
      return 'Expert completed per-COTS verification and accepted this submission.';
    }
    if (adminRejected) {
      return 'Expert completed per-COTS verification and rejected this submission.';
    }
    return switch (recordBandFromItems(items)) {
      CotsVerificationBand.aiAutoApproved =>
        'All ${items.length} detections are ${autoApproveMin}%+ confidence. Each COTS was AI auto-approved.',
      CotsVerificationBand.adminReview => () {
          final auto = countAutoApproved(items);
          final review = countNeedingAdminReview(items);
          final retake = countRetakeRequired(items);
          final parts = <String>[
            if (auto > 0)
              '$auto COTS auto-approved (${autoApproveMin}%+).',
            '$review COTS below ${autoApproveMin}% require expert verification.',
            if (retake > 0)
              '$retake COTS below ${adminReviewMin}% flagged for retake.',
          ];
          return parts.join(' ');
        }(),
      CotsVerificationBand.retakeRequired =>
        'All detections below ${adminReviewMin}% confidence. User should retake the photo.',
    };
  }

  /// Builds labeled detections for checklist + image overlay.
  static List<CotsDetectionReviewItem> buildDetectionItems({
    required int count,
    required int averagePercent,
    List<CotsBoundingBox>? boxes,
    int imageWidth = 1920,
    int imageHeight = 1080,
  }) {
    if (count <= 0) return const [];
    final resolvedBoxes = (boxes != null && boxes.length == count)
        ? boxes
        : syntheticBoundingBoxes(
            count: count,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            averagePercent: averagePercent,
          );

    return List.generate(count, (i) {
      final box = resolvedBoxes[i];
      final pct = box.confidencePercent;
      return CotsDetectionReviewItem(
        index: i + 1,
        label: 'COTS ${i + 1}',
        confidencePercent: pct,
        box: box,
      );
    });
  }

  /// Fallback box layout when Firestore has no stored detections.
  static List<CotsBoundingBox> syntheticBoundingBoxes({
    required int count,
    required int imageWidth,
    required int imageHeight,
    required int averagePercent,
  }) {
    if (count <= 0) return const [];
    final w = imageWidth > 0 ? imageWidth : 1920;
    final h = imageHeight > 0 ? imageHeight : 1080;
    final cols = math.sqrt(count).ceil().clamp(1, 10);
    final rows = (count / cols).ceil();
    final cellW = w / cols;
    final cellH = h / rows;
    const inset = 0.18;

    return List.generate(count, (i) {
      final col = i % cols;
      final row = i ~/ cols;
      final spread = ((i * 11 + averagePercent) % 23) - 11;
      final pct = ((averagePercent + spread).clamp(1, 99) / 100).toDouble();
      final bw = cellW * (0.42 + (i % 3) * 0.06);
      final bh = cellH * (0.42 + (i % 2) * 0.08);
      final cx = col * cellW + cellW / 2;
      final cy = row * cellH + cellH / 2;
      return CotsBoundingBox(
        x1: (cx - bw / 2).clamp(w * inset, w * (1 - inset) - bw),
        y1: (cy - bh / 2).clamp(h * inset, h * (1 - inset) - bh),
        x2: (cx + bw / 2).clamp(w * inset + bw, w * (1 - inset)),
        y2: (cy + bh / 2).clamp(h * inset + bh, h * (1 - inset)),
        score: pct,
      );
    });
  }

  /// @deprecated Use [buildDetectionItems].
  static List<CotsDetectionReviewItem> syntheticDetections({
    required int count,
    required int averagePercent,
  }) =>
      buildDetectionItems(count: count, averagePercent: averagePercent);
}

enum CotsVerificationBand {
  aiAutoApproved,
  adminReview,
  retakeRequired,
}

/// One labeled COTS detection on the expert verification checklist.
class CotsDetectionReviewItem {
  const CotsDetectionReviewItem({
    required this.index,
    required this.label,
    required this.confidencePercent,
    required this.box,
  });

  final int index;
  final String label;
  final int confidencePercent;
  final CotsBoundingBox box;

  CotsVerificationBand get band =>
      CotsConfidencePolicy.bandFromPercent(confidencePercent);
}

enum PerCotsAdminDecision { pending, confirmed, rejected }

extension PerCotsAdminDecisionX on PerCotsAdminDecision {
  String get label => switch (this) {
        PerCotsAdminDecision.pending => 'Pending',
        PerCotsAdminDecision.confirmed => 'Confirmed',
        PerCotsAdminDecision.rejected => 'Rejected',
      };

  String get storageValue => name;

  static PerCotsAdminDecision fromStorage(Object? value) =>
      switch ('$value') {
        'confirmed' => PerCotsAdminDecision.confirmed,
        'rejected' => PerCotsAdminDecision.rejected,
        _ => PerCotsAdminDecision.pending,
      };

  static List<PerCotsAdminDecision> listFromStorage(Object? value) {
    if (value is! List) return const [];
    return value.map(fromStorage).toList();
  }

  static List<String> listToStorage(List<PerCotsAdminDecision> decisions) =>
      decisions.map((d) => d.storageValue).toList();
}
