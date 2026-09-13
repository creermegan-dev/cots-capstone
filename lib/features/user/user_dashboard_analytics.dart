import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../models/cots_confidence_policy.dart';
import '../../models/scan_record_model.dart';

/// Aggregated metrics for the user dashboard and analytics overview.
class UserDashboardAnalytics {
  const UserDashboardAnalytics({
    required this.totalCots,
    required this.totalScans,
    required this.clearedZones,
    required this.avgDensity,
    required this.densityLabel,
    required this.lastUpdated,
    required this.cotsTrendPct,
    required this.scansTrendPct,
    required this.clearedTrendPct,
    required this.periodLabel,
    required this.dailyTrendLabels,
    required this.dailyTrendValues,
    required this.zoneSlices,
    required this.severityHigh,
    required this.severityMedium,
    required this.severityLow,
    required this.confidenceRows,
    required this.isSampleData,
  });

  final int totalCots;
  final int totalScans;
  final int clearedZones;
  final double avgDensity;
  final String densityLabel;
  final DateTime? lastUpdated;
  final double cotsTrendPct;
  final double scansTrendPct;
  final double clearedTrendPct;
  final String periodLabel;
  final List<String> dailyTrendLabels;
  final List<double> dailyTrendValues;
  final List<ZoneSlice> zoneSlices;
  final int severityHigh;
  final int severityMedium;
  final int severityLow;
  final List<ConfidenceRow> confidenceRows;
  final bool isSampleData;

  List<FlSpot> get dailyTrendSpots {
    if (dailyTrendValues.isEmpty) return const [];
    return [
      for (var i = 0; i < dailyTrendValues.length; i++)
        FlSpot(i.toDouble(), dailyTrendValues[i]),
    ];
  }

  double get maxTrendY {
    if (dailyTrendValues.isEmpty) return 100;
    final m = dailyTrendValues.reduce(math.max);
    if (m <= 0) return 25;
    return ((m / 25).ceil() * 25).toDouble().clamp(25, 999);
  }

  double get maxSeverityY {
    final m = math.max(severityHigh, math.max(severityMedium, severityLow));
    if (m <= 0) return 30;
    return ((m / 30).ceil() * 30).toDouble().clamp(30, 999);
  }

  factory UserDashboardAnalytics.fromRecords(List<ScanRecordModel> records) {
    if (records.isEmpty) return UserDashboardAnalytics.sample();

    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final prevWeekStart = weekStart.subtract(const Duration(days: 7));
    final prevWeekEnd = weekStart.subtract(const Duration(days: 1));

    bool inRange(DateTime? d, DateTime start, DateTime end) {
      if (d == null) return false;
      final day = DateTime(d.year, d.month, d.day);
      return !day.isBefore(start) && !day.isAfter(end);
    }

    final current = records.where(
      (r) => inRange(r.submittedAt ?? r.dateTaken, weekStart, now),
    );
    final previous = records.where(
      (r) => inRange(
        r.submittedAt ?? r.dateTaken,
        prevWeekStart,
        prevWeekEnd,
      ),
    );

    int sumCots(Iterable<ScanRecordModel> list) =>
        list.fold(0, (s, r) => s + r.aiDetectedCount);

    final totalCots = sumCots(records);
    final totalScans = records.length;
    final zones = records.map((r) => r.zone).where((z) => z.isNotEmpty).toSet();
    final activeZoneCount = records
        .where((r) => r.aiDetectedCount >= 5)
        .map((r) => r.zone)
        .toSet()
        .length;
    final clearedZones = math.max(0, zones.length - activeZoneCount);

    final densities = records
        .map((r) => r.aiDetectedCount <= 0 ? 0.0 : r.aiDetectedCount * 0.36)
        .where((d) => d > 0);
    final avgDensity = densities.isEmpty
        ? 0.0
        : densities.reduce((a, b) => a + b) / densities.length;

    final cotsTrend = _pctChange(sumCots(current), sumCots(previous));
    final scansTrend = _pctChange(current.length, previous.length);
    final prevCleared = math.max(
      0,
      previous.map((r) => r.zone).toSet().length -
          previous.where((r) => r.aiDetectedCount >= 5).map((r) => r.zone).toSet().length,
    );
    final currCleared = clearedZones;
    final clearedTrend = _pctChange(currCleared, prevCleared);

    final periodLabel =
        '${DateFormat('MMM d').format(weekStart)} – ${DateFormat('MMM d').format(now)}';

    final labels = <String>[];
    final values = <double>[];
    for (var i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      labels.add(DateFormat('MMM d').format(day));
      final dayCots = records
          .where((r) {
            final when = r.submittedAt ?? r.dateTaken;
            if (when == null) return false;
            final d = DateTime(when.year, when.month, when.day);
            return d == day;
          })
          .fold<int>(0, (s, r) => s + r.aiDetectedCount);
      values.add(dayCots.toDouble());
    }

    final zoneMap = <String, int>{};
    for (final r in records) {
      final z = r.zone.isEmpty ? 'Unassigned' : r.zone;
      zoneMap[z] = (zoneMap[z] ?? 0) + r.aiDetectedCount;
    }
    final zoneSlices = _zoneSlicesFromMap(zoneMap);

    var high = 0, medium = 0, low = 0;
    for (final r in records) {
      final c = r.aiDetectedCount;
      if (c >= 15) {
        high += c;
      } else if (c >= 5) {
        medium += c;
      } else {
        low += c;
      }
    }

    var confHigh = 0, confMed = 0, confLow = 0;
    for (final r in records) {
      final pct = CotsConfidencePolicy.percentFromConfidence(r.confidence);
      final c = r.aiDetectedCount;
      if (pct >= CotsConfidencePolicy.autoApproveMin) {
        confHigh += c;
      } else if (pct >= CotsConfidencePolicy.adminReviewMin) {
        confMed += c;
      } else {
        confLow += c;
      }
    }
    final confTotal = math.max(1, confHigh + confMed + confLow);
    final confidenceRows = [
      ConfidenceRow(
        label: 'High (≥ ${CotsConfidencePolicy.autoApproveMin}%) — Automatically Accepted',
        detections: confHigh,
        percent: confHigh / confTotal,
        description: 'Automatically accepted at 80%–100% confidence.',
        color: ConfidenceRow.green,
      ),
      ConfidenceRow(
        label: 'Medium (${CotsConfidencePolicy.adminReviewMin}–${CotsConfidencePolicy.autoApproveMin - 1}%) — Requires Expert Validation',
        detections: confMed,
        percent: confMed / confTotal,
        description: 'Forwarded to Expert for manual verification.',
        color: ConfidenceRow.orange,
      ),
      ConfidenceRow(
        label: 'Low (< ${CotsConfidencePolicy.adminReviewMin}%) — Retake photo',
        detections: confLow,
        percent: confLow / confTotal,
        description: 'User should retake the GoPro image.',
        color: ConfidenceRow.red,
      ),
    ];

    DateTime? lastUpdated;
    for (final r in records) {
      final when = r.submittedAt ?? r.dateTaken;
      if (when != null && (lastUpdated == null || when.isAfter(lastUpdated))) {
        lastUpdated = when;
      }
    }

    return UserDashboardAnalytics(
      totalCots: totalCots,
      totalScans: totalScans,
      clearedZones: clearedZones,
      avgDensity: avgDensity,
      densityLabel: _densityLabel(avgDensity),
      lastUpdated: lastUpdated,
      cotsTrendPct: cotsTrend,
      scansTrendPct: scansTrend,
      clearedTrendPct: clearedTrend,
      periodLabel: periodLabel,
      dailyTrendLabels: labels,
      dailyTrendValues: values,
      zoneSlices: zoneSlices,
      severityHigh: high,
      severityMedium: medium,
      severityLow: low,
      confidenceRows: confidenceRows,
      isSampleData: false,
    );
  }

  factory UserDashboardAnalytics.sample() {
    return UserDashboardAnalytics(
      totalCots: 1248,
      totalScans: 12,
      clearedZones: 5,
      avgDensity: 3.6,
      densityLabel: 'Moderate',
      lastUpdated: DateTime.now(),
      cotsTrendPct: 12.5,
      scansTrendPct: 9.1,
      clearedTrendPct: 0,
      periodLabel: 'May 23 – May 29',
      dailyTrendLabels: const [
        'May 12',
        'May 13',
        'May 14',
        'May 15',
        'May 16',
        'May 17',
        'May 18',
      ],
      dailyTrendValues: const [42, 55, 48, 72, 65, 88, 78],
      zoneSlices: const [
        ZoneSlice('Zone A — North Reef', 78, 0xFF2563EB),
        ZoneSlice('Zone B — South Reef', 62, 0xFF3FA34D),
        ZoneSlice('Zone C — East Reef', 52, 0xFFF6A623),
        ZoneSlice('Zone D — West Reef', 36, 0xFF7C3AED),
        ZoneSlice('Other Zones', 20, 0xFF90A4AE),
      ],
      severityHigh: 98,
      severityMedium: 92,
      severityLow: 58,
      confidenceRows: const [
        ConfidenceRow(
          label: 'High (≥ 80%) — Automatically Accepted',
          detections: 182,
          percent: 0.734,
          description: 'Automatically accepted at 80%–100% confidence.',
          color: ConfidenceRow.green,
        ),
        ConfidenceRow(
          label: 'Medium (20–79%) — Requires Expert Validation',
          detections: 48,
          percent: 0.194,
          description: 'Forwarded to Expert for manual verification.',
          color: ConfidenceRow.orange,
        ),
        ConfidenceRow(
          label: 'Low (< 20%) — Retake photo',
          detections: 18,
          percent: 0.072,
          description: 'User should retake the GoPro image.',
          color: ConfidenceRow.red,
        ),
      ],
      isSampleData: true,
    );
  }

  static double _pctChange(num current, num previous) {
    if (previous == 0) return current == 0 ? 0 : 100;
    return ((current - previous) / previous) * 100;
  }

  static String _densityLabel(double d) {
    if (d >= 5) return 'High';
    if (d >= 2.5) return 'Moderate';
    return 'Low';
  }

  static List<ZoneSlice> _zoneSlicesFromMap(Map<String, int> zoneMap) {
    const palette = [
      0xFF2563EB,
      0xFF3FA34D,
      0xFFF6A623,
      0xFF7C3AED,
      0xFF90A4AE,
    ];
    final sorted = zoneMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(4).toList();
    var other = 0;
    for (var i = 4; i < sorted.length; i++) {
      other += sorted[i].value;
    }
    final slices = <ZoneSlice>[
      for (var i = 0; i < top.length; i++)
        ZoneSlice(top[i].key, top[i].value, palette[i]),
    ];
    if (other > 0) {
      slices.add(ZoneSlice('Other Zones', other, palette[4]));
    }
    return slices;
  }
}

class ZoneSlice {
  const ZoneSlice(this.label, this.count, this.colorValue);

  final String label;
  final int count;
  final int colorValue;

  double shareOf(int total) => total == 0 ? 0 : count / total;
}

class ConfidenceRow {
  const ConfidenceRow({
    required this.label,
    required this.detections,
    required this.percent,
    required this.description,
    required this.color,
  });

  static const green = 0xFF3FA34D;
  static const orange = 0xFFF6A623;
  static const red = 0xFFE74C3C;

  final String label;
  final int detections;
  final double percent;
  final String description;
  final int color;
}
