import 'package:flutter/material.dart';

/// Snapshot passed into report modals (built from the reports table row).
class AdminReportModalData {
  const AdminReportModalData({
    required this.id,
    required this.typeLabel,
    required this.typeColor,
    required this.submittedBy,
    required this.zoneShort,
    required this.zoneLong,
    required this.submittedOn,
    required this.confidencePct,
    required this.statusLabel,
    required this.isForReview,
    required this.cotsCount,
    required this.reviewDetailsLine,
    required this.detectionMethod,
    required this.gpsCoordinates,
    required this.detectedDate,
    required this.detectedTime,
    required this.recordedRole,
    required this.waterVisibility,
    required this.weather,
    required this.depthRange,
    required this.notes,
    required this.imageUrls,
    this.falsePositives = 0,
    this.otherMarine = 0,
    this.totalAreaM2 = 1250,
  });

  final String id;
  final String typeLabel;
  final Color typeColor;
  final String submittedBy;
  final String zoneShort;
  final String zoneLong;
  final String submittedOn;
  final int confidencePct;
  final String statusLabel;
  final bool isForReview;
  final int cotsCount;
  final String reviewDetailsLine;
  final String detectionMethod;
  final String gpsCoordinates;
  final String detectedDate;
  final String detectedTime;
  final String recordedRole;
  final String waterVisibility;
  final String weather;
  final String depthRange;
  final String notes;
  final List<String> imageUrls;
  final int falsePositives;
  final int otherMarine;
  final int totalAreaM2;

  String get confidenceBand {
    if (confidencePct >= 85) return 'High';
    if (confidencePct >= 60) return 'Medium';
    return 'Low';
  }

  Color get confidenceAccentColor {
    if (confidencePct >= 85) return const Color(0xFF43A047);
    if (confidencePct >= 60) return const Color(0xFFF9A825);
    return const Color(0xFFE53935);
  }

  String get confidenceDescription {
    if (confidencePct >= 85) return 'High confidence detection.';
    if (confidencePct >= 60) return 'This report requires admin review.';
    return 'Low confidence — verify in the field.';
  }

  int get totalCotsTable => cotsCount;
  double get cotsPct => totalCotsTable == 0 ? 0 : 100.0;

  AdminReportModalData copyWith({
    String? id,
    String? typeLabel,
    Color? typeColor,
    String? submittedBy,
    String? zoneShort,
    String? zoneLong,
    String? submittedOn,
    int? confidencePct,
    String? statusLabel,
    bool? isForReview,
    int? cotsCount,
    String? reviewDetailsLine,
    String? detectionMethod,
    String? gpsCoordinates,
    String? detectedDate,
    String? detectedTime,
    String? recordedRole,
    String? waterVisibility,
    String? weather,
    String? depthRange,
    String? notes,
    List<String>? imageUrls,
    int? falsePositives,
    int? otherMarine,
    int? totalAreaM2,
  }) {
    return AdminReportModalData(
      id: id ?? this.id,
      typeLabel: typeLabel ?? this.typeLabel,
      typeColor: typeColor ?? this.typeColor,
      submittedBy: submittedBy ?? this.submittedBy,
      zoneShort: zoneShort ?? this.zoneShort,
      zoneLong: zoneLong ?? this.zoneLong,
      submittedOn: submittedOn ?? this.submittedOn,
      confidencePct: confidencePct ?? this.confidencePct,
      statusLabel: statusLabel ?? this.statusLabel,
      isForReview: isForReview ?? this.isForReview,
      cotsCount: cotsCount ?? this.cotsCount,
      reviewDetailsLine: reviewDetailsLine ?? this.reviewDetailsLine,
      detectionMethod: detectionMethod ?? this.detectionMethod,
      gpsCoordinates: gpsCoordinates ?? this.gpsCoordinates,
      detectedDate: detectedDate ?? this.detectedDate,
      detectedTime: detectedTime ?? this.detectedTime,
      recordedRole: recordedRole ?? this.recordedRole,
      waterVisibility: waterVisibility ?? this.waterVisibility,
      weather: weather ?? this.weather,
      depthRange: depthRange ?? this.depthRange,
      notes: notes ?? this.notes,
      imageUrls: imageUrls ?? this.imageUrls,
      falsePositives: falsePositives ?? this.falsePositives,
      otherMarine: otherMarine ?? this.otherMarine,
      totalAreaM2: totalAreaM2 ?? this.totalAreaM2,
    );
  }
}
