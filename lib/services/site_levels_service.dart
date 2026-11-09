import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Monthly site levels (user + Expert, 2026-11-08): a site's level is the
/// number of CONFIRMED COTS recorded at the whole site in one calendar month.
abstract final class MonthlySiteLevel {
  static const lowUpTo = 15;
  static const moderateUpTo = 100;

  static String levelFor(int confirmedCots) => confirmedCots <= lowUpTo
      ? 'Low'
      : confirmedCots <= moderateUpTo
          ? 'Moderate'
          : 'High';

  static final _monthFormat = DateFormat('MMM yyyy');
  static String monthLabel(DateTime month) => _monthFormat.format(month);

  /// The calendar month (Philippine time) of a moment.
  static DateTime monthOf(DateTime when) {
    final ph = when.toUtc().add(const Duration(hours: 8));
    return DateTime(ph.year, ph.month);
  }
}

/// One site's level for one month (no records that month = no level).
class SiteLevel {
  const SiteLevel({
    required this.areaCode,
    required this.areaName,
    this.mapZone,
    this.level,
    this.month,
    this.densityPerHa,
    this.assessedAt,
    this.records = 0,
    this.confirmedCots = 0,
    this.waitingCots = 0,
  });

  factory SiteLevel.fromJson(Map<String, dynamic> json) {
    final month = DateTime.tryParse(json['month']?.toString() ?? '');
    return SiteLevel(
      areaCode: json['area_code']?.toString() ?? '',
      areaName: json['area_name']?.toString() ?? '',
      mapZone: json['map_zone']?.toString(),
      level: json['level']?.toString(),
      month: month == null ? null : DateTime(month.year, month.month),
      densityPerHa: (json['density_per_ha'] as num?)?.toDouble(),
      assessedAt: DateTime.tryParse(json['assessed_at']?.toString() ?? ''),
      records: (json['records'] as num?)?.toInt() ?? 0,
      confirmedCots: (json['confirmed_cots'] as num?)?.toInt() ?? 0,
      waitingCots: (json['waiting_cots'] as num?)?.toInt() ?? 0,
    );
  }

  final String areaCode;
  final String areaName;
  final String? mapZone;

  /// 'Low', 'Moderate' or 'High'; null when the site has no records.
  final String? level;

  /// The month the level is for (first day of the month).
  final DateTime? month;

  /// Older per-hectare level (kept for older data; not used by the map).
  final double? densityPerHa;
  final DateTime? assessedAt;
  final int records;
  final int confirmedCots;
  final int waitingCots;

  bool get isPractice => mapZone == 'Practice' || areaCode.startsWith('P');
}

/// Reads the monthly site levels. Tests replace it.
class SiteLevelsApi {
  const SiteLevelsApi();

  static List<SiteLevel> _parse(dynamic rows) => [
        for (final row in (rows as List?) ?? const [])
          SiteLevel.fromJson(Map<String, dynamic>.from(row as Map)),
      ];

  /// Each site's level for [month], or its latest month with records when
  /// [month] is null.
  Future<List<SiteLevel>> monthLevels([DateTime? month]) async => _parse(
      await Supabase.instance.client.rpc<dynamic>('site_month_levels_json',
          params: {
            'p_month': month == null
                ? null
                : DateFormat('yyyy-MM-01').format(month),
          }));

  /// Every site and month with records in the last [months] months.
  Future<List<SiteLevel>> history({int months = 12}) async => _parse(
      await Supabase.instance.client.rpc<dynamic>('site_month_history_json',
          params: {'p_months': months}));

  /// Kept for older callers: the latest month of each site.
  Future<List<SiteLevel>> levels() => monthLevels();
}
