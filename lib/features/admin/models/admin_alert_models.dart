import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

enum AdminAlertSeverity { high, moderate, low }

enum AdminAlertStatus { new_, inProgress, resolved }

enum AdminAlertType {
  cotsDetected,
  highDensity,
  outbreak,
  equipment,
}

extension AdminAlertTypeX on AdminAlertType {
  String get label => switch (this) {
        AdminAlertType.cotsDetected => 'COTS Detected',
        AdminAlertType.highDensity => 'High Density Alert',
        AdminAlertType.outbreak => 'Outbreak Alert',
        AdminAlertType.equipment => 'Equipment Notice',
      };

  IconData get icon => switch (this) {
        AdminAlertType.cotsDetected => Icons.shield_outlined,
        AdminAlertType.highDensity => Icons.warning_amber_rounded,
        AdminAlertType.outbreak => Icons.bubble_chart_outlined,
        AdminAlertType.equipment => Icons.sensors_outlined,
      };

  Color get iconColor => switch (this) {
        AdminAlertType.cotsDetected => AdminColors.statRed,
        AdminAlertType.highDensity => AdminColors.statYellow,
        AdminAlertType.outbreak => AdminColors.statYellow,
        AdminAlertType.equipment => AdminColors.statBlue,
      };
}

extension AdminAlertStatusX on AdminAlertStatus {
  String get label => switch (this) {
        AdminAlertStatus.new_ => 'New',
        AdminAlertStatus.inProgress => 'In Progress',
        AdminAlertStatus.resolved => 'Resolved',
      };

  (Color fg, Color bg) get colors => switch (this) {
        AdminAlertStatus.new_ => (const Color(0xFF1565C0), const Color(0xFFE3F2FD)),
        AdminAlertStatus.inProgress => (const Color(0xFF0277BD), const Color(0xFFE1F5FE)),
        AdminAlertStatus.resolved => (AdminColors.statGreen, AdminColors.statGreen.withValues(alpha: 0.14)),
      };
}

extension AdminAlertSeverityX on AdminAlertSeverity {
  String get label => switch (this) {
        AdminAlertSeverity.high => 'High',
        AdminAlertSeverity.moderate => 'Moderate',
        AdminAlertSeverity.low => 'Low',
      };

  Color get color => switch (this) {
        AdminAlertSeverity.high => AdminColors.statRed,
        AdminAlertSeverity.moderate => AdminColors.statYellow,
        AdminAlertSeverity.low => AdminColors.statGreen,
      };
}

/// Row in the Alerts list table.
class AdminAlertListRow {
  const AdminAlertListRow(
    this.id,
    this.type,
    this.zone,
    this.message,
    this.severity,
    this.status,
    this.detectedOn,
  );

  final String id;
  final AdminAlertType type;
  final String zone;
  final String message;
  final AdminAlertSeverity severity;
  final AdminAlertStatus status;
  final String detectedOn;

  String get typeLabel => type.label;
}

/// Full detail payload for [AdminAlertDetailsScreen].
class AdminAlertDetailsData {
  const AdminAlertDetailsData({
    required this.id,
    required this.type,
    required this.zoneTitle,
    required this.siteArea,
    required this.severity,
    required this.whyHighTitle,
    required this.whyHighDescription,
    required this.status,
    required this.confidencePercent,
    required this.confidenceBlurb,
    required this.detectedOn,
    required this.alertedOn,
    required this.messageHeading,
    required this.cotsCount,
    required this.density,
    required this.threshold,
    required this.riskLevel,
    required this.whatDoesThisMean,
    required this.actionRecommended,
    required this.depthM,
    required this.observer,
    required this.detectionMethod,
    required this.waterVisibility,
    required this.remarks,
    required this.imageQuality,
    required this.visibilityIndex,
    required this.detectionClarity,
    required this.algorithmModel,
    required this.confidenceLongDescription,
    required this.imageUrl,
    required this.imageCaption,
    required this.latitude,
    required this.longitude,
    required this.notes,
  });

  final String id;
  final AdminAlertType type;
  final String zoneTitle;
  final String siteArea;
  final AdminAlertSeverity severity;
  final String whyHighTitle;
  final String whyHighDescription;
  final AdminAlertStatus status;
  final int confidencePercent;
  final String confidenceBlurb;
  final String detectedOn;
  final String alertedOn;
  final String messageHeading;
  final int cotsCount;
  final double density;
  final double threshold;
  final String riskLevel;
  final String whatDoesThisMean;
  final String actionRecommended;
  final double depthM;
  final String observer;
  final String detectionMethod;
  final String waterVisibility;
  final String remarks;
  final String imageQuality;
  final String visibilityIndex;
  final String detectionClarity;
  final String algorithmModel;
  final String confidenceLongDescription;
  final String imageUrl;
  final String imageCaption;
  final double latitude;
  final double longitude;
  final String notes;

  factory AdminAlertDetailsData.fromListRow(AdminAlertListRow row) {
    if (row.id == 'ALT-2026-0006') {
      return AdminAlertDetailsData(
        id: row.id,
        type: row.type,
        zoneTitle: '${row.zone} — North Reef',
        siteArea: 'North Reef',
        severity: row.severity,
        whyHighTitle: 'Why High?',
        whyHighDescription:
            'The detected COTS density (18.4 /100 m²) exceeds the threshold (>10 /100 m²) for this zone.',
        status: row.status,
        confidencePercent: 87,
        confidenceBlurb: 'Based on image quality, visibility and detection clarity.',
        detectedOn: row.detectedOn,
        alertedOn: 'May 18, 2026 09:16 AM',
        messageHeading: 'COTS detected in monitored area.',
        cotsCount: 7,
        density: 18.4,
        threshold: 10,
        riskLevel: 'High',
        whatDoesThisMean:
            'The observer recorded a total of 7 Crown-of-Thorns Starfish (COTS) in the surveyed area.',
        actionRecommended: 'Remove at least 7 COTS to bring the density below the long-term threshold.',
        depthM: 5.2,
        observer: 'Juan Dela Cruz (DVR-004)',
        detectionMethod: 'Underwater Visual Survey',
        waterVisibility: 'Good (15–20 m)',
        remarks: 'COTS observed on reef slope with active feeding.',
        imageQuality: 'Good',
        visibilityIndex: '85%',
        detectionClarity: 'High',
        algorithmModel: 'COTS Detection Model v2.1',
        confidenceLongDescription: 'Clear COTS features detected in high-quality image with good visibility.',
        imageUrl:
            'https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=1400&q=80',
        imageCaption: 'Captured on May 18, 2026 09:10 AM',
        latitude: 9.123456,
        longitude: 123.456789,
        notes: 'Initial detection recorded during routine COTS monitoring survey.',
      );
    }

    final site = '${row.zone} site';
    final dens = row.message.contains('78.40') ? 78.40 : (row.severity == AdminAlertSeverity.high ? 22.0 : 12.0);
    const thresh = 10.0;
    final cots = row.message.contains('7 individuals') ? 7 : (row.severity == AdminAlertSeverity.high ? 5 : 2);
    return AdminAlertDetailsData(
      id: row.id,
      type: row.type,
      zoneTitle: '${row.zone} — $site',
      siteArea: site,
      severity: row.severity,
      whyHighTitle: 'Why ${row.severity.label}?',
      whyHighDescription:
          'The detected COTS density (${dens.toStringAsFixed(1)} /100 m²) compared to threshold (>${thresh.toStringAsFixed(0)} /100 m²) for this zone.',
      status: row.status,
      confidencePercent: 72 + row.id.hashCode.abs() % 23,
      confidenceBlurb: 'Based on image quality, visibility and detection clarity.',
      detectedOn: row.detectedOn,
      alertedOn: row.detectedOn,
      messageHeading: () {
        final head = row.message.split('.').first.trim();
        return head.isEmpty ? row.message : '$head.';
      }(),
      cotsCount: cots,
      density: dens,
      threshold: thresh,
      riskLevel: row.severity.label,
      whatDoesThisMean: 'Field observation recorded $cots COTS in the surveyed area for this alert.',
      actionRecommended: 'Review monitoring protocol and schedule follow-up as needed.',
      depthM: 4.0 + (row.id.hashCode.abs() % 15) / 10,
      observer: 'Field Observer (${row.id.substring(row.id.length - 4)})',
      detectionMethod: 'Underwater Visual Survey',
      waterVisibility: 'Good (10–18 m)',
      remarks: row.message,
      imageQuality: 'Good',
      visibilityIndex: '80%',
      detectionClarity: row.severity == AdminAlertSeverity.high ? 'High' : 'Moderate',
      algorithmModel: 'COTS Detection Model v2.1',
      confidenceLongDescription: 'Automated assessment from survey imagery and environmental inputs.',
      imageUrl:
          'https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=1400&q=80',
      imageCaption: 'Captured during survey — ${row.detectedOn}',
      latitude: 9.0 + (row.id.hashCode.abs() % 50) / 1000,
      longitude: 123.0 + (row.id.hashCode.abs() % 80) / 1000,
      notes: 'See alert message for initial notes.',
    );
  }
}
