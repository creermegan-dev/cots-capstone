import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../models/monitoring_analytics.dart';
import '../../models/scan_record_model.dart';

class UserDashboardAnalytics {
  UserDashboardAnalytics.fromRecords(List<ScanRecordModel> records,
      {DateTime? now}) {
    final end = MonitoringAnalytics.day(now ?? DateTime.now());
    final start = end.subtract(const Duration(days: 6));
    final data = MonitoringAnalytics.fromRecords(records);
    final current =
        MonitoringAnalytics.fromRecords(records, from: start, to: end);
    final previous = MonitoringAnalytics.fromRecords(records,
        from: start.subtract(const Duration(days: 7)),
        to: start.subtract(const Duration(days: 1)));
    totalCots = data.totalCots;
    totalScans = data.captures.length;
    cotsTrendPct = _change(current.totalCots, previous.totalCots);
    scansTrendPct = _change(current.captures.length, previous.captures.length);
    periodLabel =
        '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d').format(end)}';
    final points = data.trend(start, end, 'Daily');
    dailyTrendValues = [for (final p in points) p.count.toDouble()];
    for (final r in data.captures) {
      final date = r.submittedAt ?? r.dateTaken;
      if (date != null && (lastUpdated == null || date.isAfter(lastUpdated!))) {
        lastUpdated = date;
      }
    }
  }

  late final int totalCots, totalScans;
  late final double? cotsTrendPct, scansTrendPct;
  late final String periodLabel;
  late final List<double> dailyTrendValues;
  DateTime? lastUpdated;
  List<FlSpot> get dailyTrendSpots => [
        for (var i = 0; i < dailyTrendValues.length; i++)
          FlSpot(i.toDouble(), dailyTrendValues[i])
      ];
  double get maxTrendY =>
      math.max(1, dailyTrendValues.fold<double>(0, math.max));
  static double? _change(int current, int previous) =>
      previous == 0 ? null : (current - previous) * 100 / previous;
}
