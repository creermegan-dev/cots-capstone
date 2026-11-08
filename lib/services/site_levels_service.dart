import 'package:supabase_flutter/supabase_flutter.dart';

/// Stage 13: one site's level on the map, from its latest Expert-confirmed
/// monthly visit (no level yet = "No data yet"), with its totals.
class SiteLevel {
  const SiteLevel({
    required this.areaCode,
    required this.areaName,
    this.level,
    this.densityPerHa,
    this.assessedAt,
    this.records = 0,
    this.confirmedCots = 0,
  });

  factory SiteLevel.fromJson(Map<String, dynamic> json) => SiteLevel(
        areaCode: json['area_code']?.toString() ?? '',
        areaName: json['area_name']?.toString() ?? '',
        level: json['level']?.toString(),
        densityPerHa: (json['density_per_ha'] as num?)?.toDouble(),
        assessedAt: DateTime.tryParse(json['assessed_at']?.toString() ?? ''),
        records: (json['records'] as num?)?.toInt() ?? 0,
        confirmedCots: (json['confirmed_cots'] as num?)?.toInt() ?? 0,
      );

  final String areaCode;
  final String areaName;

  /// 'Low', 'Moderate' or 'High'; null when no visit has been assessed yet.
  final String? level;
  final double? densityPerHa;
  final DateTime? assessedAt;
  final int records;
  final int confirmedCots;
}

/// Stage 13: reads the site levels for the map. Tests replace it.
class SiteLevelsApi {
  const SiteLevelsApi();

  Future<List<SiteLevel>> levels() async => [
        for (final row in (await Supabase.instance.client
                .rpc<dynamic>('site_levels_json') as List?) ??
            const [])
          SiteLevel.fromJson(Map<String, dynamic>.from(row as Map)),
      ];
}
